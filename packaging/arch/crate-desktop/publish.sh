#!/usr/bin/env bash
# Package Crate Desktop from a Crate checkout's Tauri .deb and add it to the
# local [ryoku-fork] pacman repository (see the Ryoku fork's bin/ryoku-fork-repo),
# so it installs and updates with `pacman -Syu` beside the desktop.
#
#   packaging/arch/crate-desktop/publish.sh [CRATE_CHECKOUT]
#
# Build the .deb first, in the checkout:
#   cd CRATE_CHECKOUT/app/listen-desktop && node scripts/tauri-cli.mjs build --bundles deb
# The version is the checkout's `git describe` (v3.3.1-137-gSHA -> 3.3.1.r137.gSHA).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
checkout=${1:-$HOME/Code/Ninja/crate-agents/linux-desktop}
repo_dir=${RYOKU_FORK_REPO:-/srv/ryoku-fork}
build_dir=${CRATE_DESKTOP_BUILD:-$HOME/.cache/ryoku/crate-desktop-build}

die() { echo "publish.sh: $*" >&2; exit 1; }

[ -d "$repo_dir" ] && [ -w "$repo_dir" ] || die "$repo_dir is missing or not writable"
# a Tauri build regenerates the vendored plugins' permission files; those are
# build output, not source, so they do not count as uncommitted work
git -C "$checkout" diff --quiet -- . ':(exclude)app/listen-desktop/src-tauri/vendor/*/permissions/**' \
  || die "$checkout has uncommitted changes"

deb=$(ls -t "$checkout"/app/listen-desktop/src-tauri/target/release/bundle/deb/*.deb 2>/dev/null | head -1) \
  || true
[ -n "$deb" ] || die "no .deb in $checkout; build it first (see the header)"
# the .deb must come from the commit being versioned
[ "$(stat -c %Y "$deb")" -ge "$(git -C "$checkout" log -1 --format=%ct)" ] \
  || die "$deb predates the checkout's HEAD; rebuild it"

pkgver=$(git -C "$checkout" describe --tags --long | sed -E 's/^v//; s/-([0-9]+)-g/.r\1.g/')
echo "packaging crate-desktop $pkgver from $(basename "$deb")"

mkdir -p "$build_dir"
run_makepkg() {
  (cd "$here" && env -i HOME="$HOME" PATH="$PATH" USER="$USER" LOGNAME="${LOGNAME:-$USER}" \
    LANG="${LANG:-C.UTF-8}" TERM="${TERM:-dumb}" CRATE_DESKTOP_DEB="$deb" CRATE_DESKTOP_PKGVER="$pkgver" \
    PKGDEST="$repo_dir" BUILDDIR="$build_dir" SRCDEST="$build_dir" makepkg "$@")
}
run_makepkg --force --noconfirm --nodeps >"$build_dir/makepkg.log" 2>&1 \
  || die "makepkg failed; see $build_dir/makepkg.log"
mapfile -t files < <(run_makepkg --packagelist)
repo-add --quiet --remove "$repo_dir/ryoku-fork.db.tar.zst" "${files[@]}"
echo "published crate-desktop $pkgver; install it with: sudo pacman -Syu crate-desktop"
