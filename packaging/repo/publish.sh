#!/usr/bin/env bash
# Build, sign and publish the [crate-for-ryoku] pacman repository: crate-for-ryoku
# (from packaging/aur/crate-for-ryoku/PKGBUILD), crate-desktop-bin (the package
# attached to the latest thecrateapp/crate release) and the Ryoku desktop
# packages built from the thecrateapp/ryoku fork (build-ryoku.sh), served as
# assets of the `repo` release of thecrateapp/crate-for-ryoku:
#
#   Server = https://github.com/thecrateapp/crate-for-ryoku/releases/download/repo
#
#   packaging/repo/publish.sh              build what is missing, sign, upload
#   packaging/repo/publish.sh --local      build and sign only (no upload)
#   packaging/repo/publish.sh --rebuild    rebuild crate-for-ryoku even if built
#   packaging/repo/publish.sh --ryoku DIR  replace the Ryoku set with the one
#                                          build-ryoku.sh wrote to DIR
#   packaging/repo/publish.sh --drop-ryoku stop shipping Ryoku packages
#
# Idempotent: a package that is already built and signed is kept, the Ryoku set
# stays the last one given until another --ryoku replaces it, the database is
# rebuilt from the packages each run, and the release ends up holding exactly
# the current packages, their signatures, the database and the public key.
#
# The Ryoku packages are GPL-3 builds of the fork, so their source must be public
# before they are: the upload stops unless thecrateapp/ryoku carries the tag
# crate-<pkgver> on the exact commit they were built from. A GPL package built
# from a third-party repository at a fetched commit (the compositor plugins)
# gets the same tag on its thecrateapp mirror, pushed here from the build's
# source cache; the mirror itself is made once with `gh repo fork`.
#
# Signing runs on this machine only. The key is CRATE_REPO_KEY (default: the
# repository signing key below); its passphrase is read from the desktop secret
# store (`secret-tool lookup service crate-for-ryoku-repo purpose gpg-signing`),
# or gpg asks for it when the store has none. Nothing secret leaves the machine.
#
# Needs: makepkg, repo-add, gpg, gh (logged in, with write access), curl, and
# crate-for-ryoku's build dependencies (python-cairo, numpy, Pillow, librsvg, and
# for the lock skins quickshell, qt6-imageformats, python-fonttools and
# python-brotli); build-ryoku.sh needs docker.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$here/../.." && pwd)
repo=crate-for-ryoku
gh_repo=${CRATE_REPO_GH:-thecrateapp/crate-for-ryoku}
crate_gh=${CRATE_APP_GH:-thecrateapp/crate}
fork_gh=${CRATE_RYOKU_GH:-thecrateapp/ryoku}
mirror_org=${CRATE_MIRROR_ORG:-thecrateapp}
tag=repo
key=${CRATE_REPO_KEY:-AD4DFA15F0A84853D4D711850EB2D64FEFAC7445}
work=${CRATE_REPO_WORK:-$HOME/.cache/crate-for-ryoku/repo}
pubkey=$here/$repo.gpg

upload=1 rebuild=0 ryoku_from= drop_ryoku=0
while (($#)); do
  case $1 in
    --local) upload=0 ;;
    --rebuild) rebuild=1 ;;
    --ryoku) ryoku_from=${2:?--ryoku needs the directory build-ryoku.sh wrote}; shift ;;
    --drop-ryoku) drop_ryoku=1 ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    *) echo "publish.sh: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "publish.sh: $*" >&2; exit 1; }
log() { echo "==> $*"; }

for tool in makepkg repo-add gpg curl bsdtar git; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done
[ "$upload" = 0 ] || command -v gh >/dev/null || die "gh is not installed"
gpg --list-secret-keys "$key" >/dev/null 2>&1 || die "the signing key $key is not in this keyring"
[ -s "$pubkey" ] || die "$pubkey is missing"

pkgs=$work/pkgs out=$work/out build=$work/build sources=$work/sources ryoku=$work/ryoku
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

# the Ryoku desktop set: replaced whole by --ryoku, kept as it is otherwise.
# Every package must be the one version the source record names, since the set
# pins itself by exact version. GitHub renames ':' in an asset name to '.', so
# the files take that name here and the database lists them under it (pacman
# reads versions from the database, never from the file name).
if [ "$drop_ryoku" = 1 ]; then
  log "dropping the Ryoku packages"
  rm -rf "$ryoku"
fi
if [ -n "$ryoku_from" ]; then
  record=$ryoku_from/crate-ryoku.source
  [ -f "$record" ] || die "$ryoku_from has no crate-ryoku.source; build the set with build-ryoku.sh"
  want_ver=$(sed -n 's/^pkgver=//p' "$record")
  read -r -a want_names <<<"$(sed -n 's/^packages=//p' "$record")"
  [ -n "$want_ver" ] && [ "${#want_names[@]}" -gt 0 ] || die "$record names no version or packages"
  rm -rf "$ryoku.new" && mkdir -p "$ryoku.new"
  got=()
  for f in "$ryoku_from"/*.pkg.tar.zst; do
    [ -f "$f" ] || continue
    info=$(bsdtar -xOf "$f" .PKGINFO)
    name=$(sed -n 's/^pkgname = //p' <<<"$info") ver=$(sed -n 's/^pkgver = //p' <<<"$info")
    [ "${ver%-*}" = "$want_ver" ] || die "$(basename "$f") is $ver, not $want_ver"
    got+=("$name")
    base=$(basename "$f")
    cp "$f" "$ryoku.new/${base//:/.}"
  done
  for name in "${want_names[@]}"; do
    printf '%s\n' "${got[@]}" | grep -qxF "$name" || die "$ryoku_from lacks $name"
  done
  [ "${#got[@]}" = "${#want_names[@]}" ] || die "$ryoku_from holds packages its record does not name"
  cp "$record" "$ryoku.new/"
  rm -rf "$ryoku" && mv "$ryoku.new" "$ryoku"
fi
ryoku_pkgs=()
ryoku_commit= ryoku_ver=
if [ -f "$ryoku/crate-ryoku.source" ]; then
  mapfile -t ryoku_pkgs < <(ls "$ryoku"/*.pkg.tar.zst)
  ryoku_commit=$(sed -n 's/^commit=//p' "$ryoku/crate-ryoku.source")
  ryoku_ver=$(sed -n 's/^pkgver=//p' "$ryoku/crate-ryoku.source")
  log "  Ryoku ${ryoku_ver} (${#ryoku_pkgs[@]} packages, fork commit ${ryoku_commit:0:12})"
fi

# keep only the current packages, each signed
for f in "$pkgs"/*.pkg.tar.zst; do
  [ "$f" = "${cfr[0]}" ] || [ "$f" = "$desktop" ] || rm -f "$f" "$f.sig"
done
current=("${cfr[0]}" "$desktop" "${ryoku_pkgs[@]}")
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
# where the Ryoku packages' source is: the fork commit and tag they were built from
[ -z "$ryoku_commit" ] || cp "$ryoku/crate-ryoku.source" "$out/crate-ryoku.source"
for f in "$out"/*.pkg.tar.zst "$out/$repo.db" "$out/$repo.files"; do
  signed_by_key "$f" || die "$(basename "$f") is not signed by $key"
done
log "repository ready in $out"
[ "$upload" = 1 ] || exit 0

# GPL-3: the fork's source for these exact builds is public before the binaries are
if [ -n "$ryoku_commit" ]; then
  ryoku_tag=crate-${ryoku_ver#*:}
  git ls-remote --tags "https://github.com/$fork_gh" "refs/tags/$ryoku_tag" "refs/tags/$ryoku_tag^{}" \
    | grep -q "^$ryoku_commit[[:space:]]" \
    || die "$fork_gh has no tag $ryoku_tag on $ryoku_commit; push the fork branch and that tag first"

  # the GPL packages built from a third-party repository: their commit, tagged on
  # the mirror, so the source stays available whatever upstream does with it
  record=$ryoku/crate-ryoku.source sources_dir=$(sed -n 's/^sources=//p' "$ryoku/crate-ryoku.source")
  mirrors=()
  while read -r pkg name commit url; do
    case $url in https://*) ;; *) continue ;; esac
    pkgfile=$(ls "$ryoku/$pkg"-[0-9]*.pkg.tar.zst 2>/dev/null | head -1)
    [ -n "$pkgfile" ] || die "$record names $pkg, which the set does not hold"
    bsdtar -xOf "$pkgfile" .PKGINFO | grep -qE '^license = (A|L)?GPL' || continue
    mirror=https://github.com/$mirror_org/$(basename "${url%.git}")
    GIT_TERMINAL_PROMPT=0 git ls-remote "$mirror" HEAD >/dev/null 2>&1 \
      || die "$pkg is GPL and built from $url; mirror it first: gh repo fork ${url#https://github.com/} --org $mirror_org --clone=false"
    if ! GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$mirror" "refs/tags/$ryoku_tag" | grep -q "^$commit[[:space:]]"; then
      [ -d "$sources_dir/$name" ] || die "the build's source cache $sources_dir/$name is gone; rebuild the set"
      log "tagging $name ${commit:0:12} as $ryoku_tag on $mirror"
      git -C "$sources_dir/$name" push -q "$mirror.git" "${commit}:refs/tags/$ryoku_tag" \
        || die "could not push $ryoku_tag to $mirror"
    fi
    mirrors+=("$pkg: $mirror/tree/$ryoku_tag (commit $commit)")
  done < <(sed -n 's/^vcs=//p' "$record")
fi

# the release: packages first, the database last, then drop what it no longer lists
log "uploading to $gh_repo, release $tag"
notes="The signed [crate-for-ryoku] pacman repository. Set it up from https://ryoku.cratemusic.app/#install; the assets change with every publish."
if [ -n "$ryoku_commit" ]; then
  notes+="

It also ships Ryoku $ryoku_ver built from the thecrateapp/ryoku fork (GPL-3). Its source is the tag $ryoku_tag: https://github.com/$fork_gh/tree/$ryoku_tag (commit $ryoku_commit; crate-ryoku.source lists the packages)."
  if [ "${#mirrors[@]}" -gt 0 ]; then
    notes+="

GPL packages built from other repositories, at the commit each was built from:"
    for m in "${mirrors[@]}"; do notes+="
- $m"; done
  fi
fi
if ! gh release view "$tag" -R "$gh_repo" >/dev/null 2>&1; then
  gh release create "$tag" -R "$gh_repo" --latest=false --title "Pacman repository" --notes "$notes"
else
  gh release edit "$tag" -R "$gh_repo" --notes "$notes"
fi
extra=()
[ -z "$ryoku_commit" ] || extra=("$out/crate-ryoku.source")
gh release upload "$tag" -R "$gh_repo" --clobber "$out"/*.pkg.tar.zst "$out"/*.pkg.tar.zst.sig "$out/$repo.gpg" "${extra[@]}"
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
