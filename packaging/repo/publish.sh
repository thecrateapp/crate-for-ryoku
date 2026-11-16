#!/usr/bin/env bash
# Build, sign and publish the [crate-for-ryoku] pacman repository: crate-for-ryoku
# (from packaging/aur/crate-for-ryoku/PKGBUILD) and crate-desktop-bin (the
# package attached to the latest thecrateapp/crate release), served as assets of
# the `repo` release of thecrateapp/crate-for-ryoku:
#
#   Server = https://github.com/thecrateapp/crate-for-ryoku/releases/download/repo
#
#   packaging/repo/publish.sh            build what is missing, sign, upload
#   packaging/repo/publish.sh --local    build and sign only (no upload)
#   packaging/repo/publish.sh --rebuild  rebuild crate-for-ryoku even if built
#
# Idempotent: a package that is already built and signed is kept, the database
# is rebuilt from the packages each run, and the release ends up holding exactly
# the current packages, their signatures, the database and the public key.
#
# Signing runs on this machine only. The key is CRATE_REPO_KEY (default: the
# repository signing key below); its passphrase is read from the desktop secret
# store (`secret-tool lookup service crate-for-ryoku-repo purpose gpg-signing`),
# or gpg asks for it when the store has none. Nothing secret leaves the machine.
#
# Needs: makepkg, repo-add, gpg, gh (logged in, with write access), curl, and
# crate-for-ryoku's build dependencies (python-cairo, numpy, Pillow, librsvg).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$here/../.." && pwd)
repo=crate-for-ryoku
gh_repo=${CRATE_REPO_GH:-thecrateapp/crate-for-ryoku}
crate_gh=${CRATE_APP_GH:-thecrateapp/crate}
tag=repo
key=${CRATE_REPO_KEY:-AD4DFA15F0A84853D4D711850EB2D64FEFAC7445}
work=${CRATE_REPO_WORK:-$HOME/.cache/crate-for-ryoku/repo}
pubkey=$here/$repo.gpg

upload=1 rebuild=0
for arg in "$@"; do
  case $arg in
    --local) upload=0 ;;
    --rebuild) rebuild=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "publish.sh: unknown option $arg" >&2; exit 2 ;;
  esac
done

die() { echo "publish.sh: $*" >&2; exit 1; }
log() { echo "==> $*"; }

for tool in makepkg repo-add gpg curl; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done
[ "$upload" = 0 ] || command -v gh >/dev/null || die "gh is not installed"
gpg --list-secret-keys "$key" >/dev/null 2>&1 || die "the signing key $key is not in this keyring"
[ -s "$pubkey" ] || die "$pubkey is missing"

pkgs=$work/pkgs out=$work/out build=$work/build sources=$work/sources
mkdir -p "$pkgs" "$out" "$build" "$sources"

passphrase=
if command -v secret-tool >/dev/null; then
  passphrase=$(secret-tool lookup service crate-for-ryoku-repo purpose gpg-signing 2>/dev/null || true)
fi
sign() { # sign FILE -> FILE.sig (binary, detached)
  if [ -n "$passphrase" ]; then
    printf '%s' "$passphrase" | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 0 \
      --local-user "$key" --detach-sign --no-armor --output "$1.sig" "$1"
  else
    gpg --yes --quiet --local-user "$key" --detach-sign --no-armor --output "$1.sig" "$1"
  fi
}
signed_by_key() { # the .sig beside FILE is a good signature by $key
  [ -f "$1.sig" ] && gpg --batch --status-fd 1 --verify "$1.sig" "$1" 2>/dev/null \
    | grep -q "^\[GNUPG:\] VALIDSIG $key "
}

# crate-for-ryoku, built by makepkg in a clean environment from the tagged source
log "building crate-for-ryoku"
recipe=$src/packaging/aur/crate-for-ryoku
run_makepkg() {
  (cd "$recipe" && env -i HOME="$HOME" PATH="$PATH" USER="$USER" LOGNAME="${LOGNAME:-$USER}" \
    LANG="${LANG:-C.UTF-8}" TERM="${TERM:-dumb}" ${PACKAGER:+PACKAGER="$PACKAGER"} \
    PKGDEST="$pkgs" BUILDDIR="$build" SRCDEST="$sources" PKGEXT=.pkg.tar.zst makepkg "$@")
}
mapfile -t cfr < <(run_makepkg --packagelist)
if [ "$rebuild" = 1 ] || [ ! -f "${cfr[0]}" ]; then
  run_makepkg --force --cleanbuild --noconfirm >"$build/makepkg.log" 2>&1 \
    || die "makepkg failed; see $build/makepkg.log"
  rm -f "${cfr[@]/%/.sig}"
fi
log "  $(basename "${cfr[0]}")"

# crate-desktop-bin, the package the latest Crate release attaches
log "fetching crate-desktop-bin from $crate_gh"
crate_tag=$(gh release view -R "$crate_gh" --json tagName -q .tagName)
asset=$(gh api "repos/$crate_gh/releases/tags/$crate_tag" \
  -q '.assets[] | select(.name | test("^crate-desktop-bin-[0-9].*-x86_64\\.pkg\\.tar\\.zst$")) | .name + " " + .digest' | head -1)
[ -n "$asset" ] || die "$crate_gh $crate_tag has no crate-desktop-bin package"
desktop=$pkgs/${asset%% *} digest=${asset#* }
if [ ! -f "$desktop" ]; then
  gh release download "$crate_tag" -R "$crate_gh" -p "$(basename "$desktop")" -D "$pkgs.tmp" --clobber
  [ "sha256:$(sha256sum "$pkgs.tmp/$(basename "$desktop")" | cut -d' ' -f1)" = "$digest" ] \
    || die "$(basename "$desktop") does not match the release digest $digest"
  mv "$pkgs.tmp/$(basename "$desktop")" "$desktop" && rmdir "$pkgs.tmp"
fi
log "  $(basename "$desktop") ($crate_tag)"

# keep only the current packages, each signed
for f in "$pkgs"/*.pkg.tar.zst; do
  [ "$f" = "${cfr[0]}" ] || [ "$f" = "$desktop" ] || rm -f "$f" "$f.sig"
done
current=("${cfr[0]}" "$desktop")
for f in "${current[@]}"; do
  signed_by_key "$f" || { log "signing $(basename "$f")"; sign "$f"; }
done

# the database, rebuilt from the packages and signed; pacman fetches $repo.db and
# $repo.files by those exact names, so they are real files, not symlinks
log "building the $repo database"
rm -rf "$out" && mkdir -p "$out"
cp "${current[@]}" "${current[@]/%/.sig}" "$out/"
(cd "$out" && repo-add --quiet --verify "$repo.db.tar.zst" ./*.pkg.tar.zst)
for kind in db files; do
  rm -f "$out/$repo.$kind"
  mv "$out/$repo.$kind.tar.zst" "$out/$repo.$kind"
  rm -f "$out/$repo.$kind.tar.zst.old"
  sign "$out/$repo.$kind"
done
cp "$pubkey" "$out/$repo.gpg"
for f in "$out"/*.pkg.tar.zst "$out/$repo.db" "$out/$repo.files"; do
  signed_by_key "$f" || die "$(basename "$f") is not signed by $key"
done
log "repository ready in $out"
[ "$upload" = 1 ] || exit 0

# the release: packages first, the database last, then drop what it no longer lists
log "uploading to $gh_repo, release $tag"
if ! gh release view "$tag" -R "$gh_repo" >/dev/null 2>&1; then
  gh release create "$tag" -R "$gh_repo" --latest=false --title "Pacman repository" \
    --notes "The signed [crate-for-ryoku] pacman repository. Set it up from https://ryoku.cratemusic.app/#install; the assets change with every publish."
fi
gh release upload "$tag" -R "$gh_repo" --clobber "$out"/*.pkg.tar.zst "$out"/*.pkg.tar.zst.sig "$out/$repo.gpg"
gh release upload "$tag" -R "$gh_repo" --clobber "$out/$repo.files" "$out/$repo.files.sig" "$out/$repo.db" "$out/$repo.db.sig"
mapfile -t keep < <(cd "$out" && ls)
while read -r name; do
  printf '%s\n' "${keep[@]}" | grep -qxF "$name" || {
    log "  removing $name"
    gh release delete-asset "$tag" "$name" -R "$gh_repo" --yes
  }
done < <(gh release view "$tag" -R "$gh_repo" --json assets -q '.assets[].name')

# what pacman will see: every file the database names, through GitHub's redirect
base=https://github.com/$gh_repo/releases/download/$tag
for name in "${keep[@]}"; do
  curl -fsSL -r 0-0 -o /dev/null "$base/$name" || die "$base/$name does not download"
done
log "published: Server = $base"
