#!/usr/bin/env bash
# The panel on the shell kit in both looks, against a mock player (no Crate, no
# MPRIS). RYOKU_SOURCE points at a Ryoku checkout when the installed plugin kit
# predates the kit re-exports (see kit-path.sh).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
plugin=$(realpath "${1:-$here/../../crate-mark}")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
source "$here/kit-path.sh"
crate_mark_kit_path "$work"
unset DISPLAY WAYLAND_DISPLAY NIRI_SOCKET SWAYSOCK DBUS_SESSION_BUS_ADDRESS
mkdir -m 700 "$work"/{runtime,config,data,cache,state,home}
mkdir -p "$work/config/ryoku"
echo '{"language":"en"}' > "$work/config/ryoku/shell.json"
export HOME="$work/home" XDG_RUNTIME_DIR="$work/runtime" XDG_CONFIG_HOME="$work/config"
export XDG_DATA_HOME="$work/data" XDG_CACHE_HOME="$work/cache" XDG_STATE_HOME="$work/state"
export QT_QPA_PLATFORM=offscreen
ln -s "$plugin/content" "$work/content"
cp "$here/kit.qml" "$work/shell.qml"
if ! timeout 25 qs -p "$work/shell.qml" > "$work/log" 2>&1 ||
    ! grep -Fq 'CRATE-MARK-KIT-PASS' "$work/log" ||
    grep -Eq 'TypeError|ReferenceError' "$work/log"; then
    cat "$work/log" >&2
    exit 1
fi
echo 'crate-mark kit: beam, buttons, chips and labels passed in both looks'
