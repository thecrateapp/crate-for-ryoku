#!/usr/bin/env bash
# Build the Ryoku desktop packages that [crate-for-ryoku] ships: every monorepo
# package of the thecrateapp/ryoku fork, at one commit, in a clean Arch Linux
# container, so they carry Arch's generic build flags (not this machine's
# -march=native) and link against the Arch repositories' libraries.
#
#   packaging/repo/build-ryoku.sh [--ref REF] [--out DIR] [--jobs N] RYOKU_CHECKOUT
#
# REF (default HEAD) is exported with `git archive`, so only committed bytes are
# built and the packages name exactly one fork commit. The packages land in
# DIR/<pkgver>/ (default DIR: ~/.cache/crate-for-ryoku/ryoku) beside
# crate-ryoku.source, which records that commit, the package names and the
# toolchain; publish.sh --ryoku DIR/<pkgver> adds them to the repository.
#
# The version is upstream's scheme for the commit (bin/ryoku-release-version
# --pkgver: <VERSION>.r<commit count>.g<short sha>, epoch 1), so the fork's
# packages sort above the upstream release they are based on and every fork
# commit maps to one version. /etc/ryoku-release says RELEASE=crate-<pkgver>.
#
# Needs docker and network access (the toolchain and the compositor plugins'
# sources are fetched at build time). Run it again with the same REF to rebuild:
# the output directory is replaced, the Go and source caches are kept.
set -euo pipefail

ref=HEAD
out=${CRATE_RYOKU_OUT:-$HOME/.cache/crate-for-ryoku/ryoku}
image=${CRATE_RYOKU_IMAGE:-archlinux:base-devel}
cores=$(nproc)
jobs=$(( cores > 8 ? cores - 6 : cores ))
checkout=

while (($#)); do
  case $1 in
    --ref) ref=${2:?}; shift 2 ;;
    --out) out=${2:?}; shift 2 ;;
    --jobs) jobs=${2:?}; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    -*) echo "build-ryoku.sh: unknown option $1" >&2; exit 2 ;;
    *) checkout=$1; shift ;;
  esac
done

die() { echo "build-ryoku.sh: $*" >&2; exit 1; }
log() { echo "==> $*"; }

[ -n "$checkout" ] || die "name the Ryoku checkout (for example ~/Code/Ninja/ryoku)"
git -C "$checkout" rev-parse --git-dir >/dev/null 2>&1 || die "$checkout is not a git checkout"
command -v docker >/dev/null || die "docker is not installed"

commit=$(git -C "$checkout" rev-parse --verify "$ref^{commit}") || die "no commit $ref in $checkout"
core=$(git -C "$checkout" show "$commit:VERSION" | tr -d '[:space:]')
core=${core%%-*}
count=$(git -C "$checkout" rev-list --count "$commit")
pkgver="$core.r$count.g${commit:0:7}"
name=$(git -C "$checkout" show "$commit:CODENAME" | tr -d '[:space:]')

dest=$out/$pkgver cache=$out/.cache
src=$cache/src-$pkgver
log "building Ryoku $pkgver (${commit:0:12}) into $dest"
rm -rf "$dest" "$src"
mkdir -p "$dest" "$src" "$cache/build" "$cache/sources" "$cache/go"

git -C "$checkout" archive --format=tar "$commit" | tar -x -C "$src"

# the monorepo packages: the PKGBUILDs whose version is the shared RYOKU_PKGVER
# (vendored third-party recipes under release/packages keep their own)
mapfile -t dirs < <(cd "$src/release/packages" && grep -l 'pkgver=\${RYOKU_PKGVER' ./*/PKGBUILD | cut -d/ -f2 | sort)
[ "${#dirs[@]}" -gt 0 ] || die "no monorepo PKGBUILD in $commit"
log "  ${#dirs[@]} packages: ${dirs[*]}"

cat >"$cache/build-in-container.sh" <<'EOF'
set -euo pipefail
pacman-key --init >/dev/null 2>&1
pacman-key --populate archlinux >/dev/null 2>&1
pacman -Sy --noconfirm --needed archlinux-keyring >/dev/null
mapfile -t tools < <(grep -vE '^[[:space:]]*(#|$)' /src/release/repo/build-toolchain.packages)
pacman -Syu --noconfirm --needed "${tools[@]}" >/dev/null
# no -debug split packages: the repository does not ship them
sed -i 's/^\(OPTIONS=(.*\) debug /\1 !debug /' /etc/makepkg.conf
useradd --uid "$HOST_UID" --create-home builder 2>/dev/null || true
chown builder /src /out /cache /cache/build /cache/sources /cache/go
pacman -Q > /out/toolchain.txt
for d in $DIRS; do
  printf '  %-28s' "$d"
  if runuser -u builder -- env -i HOME=/home/builder PATH=/usr/bin:/usr/local/bin LANG=C.UTF-8 \
      RYOKU_PKGVER="$RYOKU_PKGVER" RYOKU_RELEASE="$RYOKU_RELEASE" RYOKU_CHANNEL="$RYOKU_CHANNEL" \
      RYOKU_NAME="$RYOKU_NAME" RYOKU_COMMIT="$RYOKU_COMMIT" PACKAGER="$PACKAGER" \
      PKGDEST=/out BUILDDIR=/cache/build SRCDEST=/cache/sources PKGEXT=.pkg.tar.zst \
      GOPATH=/cache/go/path GOCACHE=/cache/go/cache GOMODCACHE=/cache/go/mod \
      MAKEFLAGS="-j$JOBS" CMAKE_BUILD_PARALLEL_LEVEL="$JOBS" CARGO_BUILD_JOBS="$JOBS" \
      bash -c "cd /src/release/packages/$d && makepkg --nodeps --force --cleanbuild --noconfirm" \
      >"/out/logs/$d.log" 2>&1; then
    echo ok
  else
    echo "FAILED (logs/$d.log)"; chown -R builder /out; exit 1
  fi
done
chown -R builder /out
EOF

mkdir -p "$dest/logs"
docker run --rm --cpus "$jobs" \
  -e HOST_UID="$(id -u)" -e DIRS="${dirs[*]}" -e JOBS="$jobs" \
  -e RYOKU_PKGVER="$pkgver" -e RYOKU_RELEASE="crate-$pkgver" -e RYOKU_CHANNEL=local \
  -e RYOKU_NAME="$name" -e RYOKU_COMMIT="$commit" \
  -e PACKAGER="Crate for Ryoku <https://github.com/thecrateapp/crate-for-ryoku>" \
  -v "$src:/src" -v "$dest:/out" -v "$cache/build:/cache/build" \
  -v "$cache/sources:/cache/sources" -v "$cache/go:/cache/go" \
  -v "$cache/build-in-container.sh:/build-in-container.sh:ro" \
  "$image" bash /build-in-container.sh \
  || die "the build failed; logs in $dest/logs"

# every package must carry the one version, or the exact pins between them break
mapfile -t built < <(cd "$dest" && ls ./*.pkg.tar.zst | sed 's#^\./##')
names=()
for f in "${built[@]}"; do
  info=$(bsdtar -xOf "$dest/$f" .PKGINFO)
  v=$(sed -n 's/^pkgver = //p' <<<"$info")
  [ "${v%-*}" = "1:$pkgver" ] || die "$f is version $v, not 1:$pkgver"
  names+=("$(sed -n 's/^pkgname = //p' <<<"$info")")
done
{
  echo "commit=$commit"
  echo "pkgver=1:$pkgver"
  echo "source=https://github.com/thecrateapp/ryoku/tree/$commit"
  echo "image=$(docker image inspect "$image" --format '{{.Id}}')"
  echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "packages=${names[*]}"
  # the third-party sources a recipe fetched or unbundled, at the commit it built
  # (the compositor plugins follow upstream HEAD when Hyprland has no pin yet)
  for d in "${dirs[@]}"; do
    for g in "$cache/build/$d"/src/*/.git; do
      [ -e "$g" ] || continue
      w=${g%/.git} n=$(basename "${g%/.git}")
      url=$(git -C "$cache/sources/$n" config remote.origin.url 2>/dev/null || echo "bundle in the fork tree")
      echo "vcs=$d $n $(git -C "$w" rev-parse HEAD 2>/dev/null) $url"
    done
  done
} >"$dest/crate-ryoku.source"
rm -rf "$src"
log "built ${#built[@]} packages in $dest"
