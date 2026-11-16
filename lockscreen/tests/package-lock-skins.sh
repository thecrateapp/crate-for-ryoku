#!/usr/bin/env bash
# The Crate lock skins are built into the package, installed per user, and the previous skin comes
# back on uninstall. Everything runs against temp dirs with stub Ryoku commands: it never touches
# the real ~/.local/share/qylock, ~/.config/qylock or ryoku-hub, and never locks anything.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# 1. build the skins into a temp dist
dist="$tmp/dist"
bash "$repo/package/build-lockscreen.sh" "$dist/lockscreen" > "$tmp/build.log" 2>&1 \
    || { cat "$tmp/build.log"; fail "build-lockscreen.sh failed"; }
for skin in hero orbit; do
    s="$dist/lockscreen/crate/$skin"
    for f in Main.qml theme.conf metadata.desktop preview.gif common/qmldir common/i18n/I18n.qml \
             common/fonts/BricolageGrotesque.ttf common/fonts/JetBrainsMono-Regular.ttf \
             common/backgrounds/groove.webp common/backgrounds/sheen.webp; do
        [ -s "$s/$f" ] || fail "$skin: missing $f"
    done
    if grep -rIl -- '\.\./common' "$s" | grep -q .; then fail "$skin still references ../common"; fi
    [ ! -e "$s/preview.sh" ] && [ ! -e "$s/common/tests" ] || fail "$skin ships test or preview files"
    python3 - "$s/preview.gif" <<'PY' || fail "$skin: preview.gif is not a looping multi-frame GIF"
import sys
from PIL import Image
im = Image.open(sys.argv[1])
assert im.format == "GIF" and im.n_frames >= 3 and im.info.get("loop", 1) == 0, (im.n_frames, im.info)
assert im.size[0] / im.size[1] > 1.5
PY
done
# the vendored background is the lifted one, not a stale darker file
python3 - "$dist/lockscreen/crate/hero/common/backgrounds/groove.webp" <<'PY' || fail "stale or dark groove background"
import sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert("L").resize((96, 60)), dtype=float)
assert a.mean() > 10, a.mean()
PY

# 2. a built skin loads on its own (the rewritten imports resolve)
PREVIEW_SKIN_ROOT="$dist/lockscreen" bash "$repo/lockscreen/preview.sh" crate/orbit idle --shot "$tmp/orbit.png" --size 800x450 \
    > "$tmp/render.log" 2>&1 || { cat "$tmp/render.log"; fail "built orbit does not render"; }
PREVIEW_SKIN_ROOT="$dist/lockscreen" bash "$repo/lockscreen/preview.sh" crate/hero idle --shot "$tmp/hero.png" --size 800x450 \
    > "$tmp/render.log" 2>&1 || { cat "$tmp/render.log"; fail "built hero does not render"; }

# 3. install and uninstall through the real scripts, with stub Ryoku commands
pkg="$tmp/pkg"
mkdir -p "$pkg/theme/crate" "$pkg/theme/fonts" "$pkg/rice"
cp -a "$repo/rice/crate" "$pkg/rice/crate"
mkdir -p "$pkg/shell" && cp "$repo/shell/eza-theme.yml" "$pkg/shell/"
mkdir -p "$pkg/apps/zapfast" && cp "$repo/apps/zapfast/Crate.json" "$pkg/apps/zapfast/" && : > "$pkg/apps/zapfast/chat.webp"
cp -a "$dist/lockscreen" "$pkg/lockscreen"
cp "$repo/package/install.sh" "$repo/package/uninstall.sh" "$repo/package/VERSION" "$pkg/"
cp "$repo/package/lock-skins.sh" "$pkg/lock-skins.sh"
mkdir -p "$tmp/bin" "$tmp/home"
log="$tmp/calls.log"; : > "$log"
for c in ryoku ryoku-hub ryoku-shell ryoku-host; do
    printf '#!/bin/sh\necho "%s $*" >> "%s"\nexit 0\n' "$c" "$log" > "$tmp/bin/$c"
    chmod +x "$tmp/bin/$c"
done
export HOME="$tmp/home" PATH="$tmp/bin:$PATH"
export XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state"
themes="$XDG_DATA_HOME/qylock/themes/crate"
state="$XDG_STATE_HOME/crate-for-ryoku"
active="$XDG_CONFIG_HOME/qylock/theme"
set_active() { mkdir -p "$(dirname "$active")"; printf '%s\n' "$1" > "$active"; }
install() { bash "$pkg/install.sh" --no-apply --no-icons --no-plugin --no-wallpapers "$@" > "$tmp/install.log" 2>&1 \
    || { cat "$tmp/install.log"; fail "install.sh failed"; }; }
uninstall() { : > "$log"; bash "$pkg/uninstall.sh" "$@" > "$tmp/uninstall.log" 2>&1 \
    || { cat "$tmp/uninstall.log"; fail "uninstall.sh failed"; }; }
installed() { [ -s "$themes/hero/Main.qml" ] && [ -s "$themes/orbit/Main.qml" ] && [ -s "$themes/orbit/common/qmldir" ]; }

# 3a. install records the previous skin once and never records a Crate skin
set_active windows_7
install
installed || fail "skins not installed under $themes"
[ "$(cat "$state/previous-lock")" = windows_7 ] || fail "previous-lock is not windows_7"
set_active crate/hero
install
[ "$(cat "$state/previous-lock")" = windows_7 ] || fail "previous-lock was overwritten"

# 3b. uninstall while a Crate skin is active restores the recorded skin, then removes ours
uninstall
grep -qx 'ryoku-hub lock set windows_7' "$log" || fail "uninstall did not run: ryoku-hub lock set windows_7 ($(grep 'lock' "$log" || echo none))"
[ ! -e "$themes/hero" ] && [ ! -e "$themes/orbit" ] || fail "skins left after uninstall"
[ ! -e "$state/previous-lock" ] || fail "previous-lock left after uninstall"

# 3c. nothing recorded: fall back to clockwork/orbital
rm -f "$active"
install
[ ! -e "$state/previous-lock" ] || fail "previous-lock written without a previous skin"
set_active crate/orbit
uninstall
grep -qx 'ryoku-hub lock set clockwork/orbital' "$log" || fail "no fallback to clockwork/orbital"

# 3d. a skin that is not ours stays: no lock set
set_active windows_7
install
uninstall
if grep -q 'lock set' "$log"; then fail "uninstall changed a skin that is not Crate's"; fi
[ ! -e "$themes/hero" ] || fail "skins left after uninstall (non-crate active)"

# 3e. --keep-files keeps skins and the active skin
set_active crate/hero
install
uninstall --keep-files
if grep -q 'lock set' "$log"; then fail "--keep-files changed the lock skin"; fi
installed || fail "--keep-files removed the skins"

# 4. the rice selects crate/hero
python3 - "$repo/rice/crate/rice.json" <<'PY' || fail "rice.json assets.lock is not crate/hero"
import json, sys
assert json.load(open(sys.argv[1]))["assets"]["lock"] == "crate/hero"
PY
echo "PASS: package-lock-skins"
