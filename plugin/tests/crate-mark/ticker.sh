#!/usr/bin/env bash
# Exercise the real bar view without launching Crate or connecting to a user's player.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
plugin=$(realpath "${1:-$here/../../crate-mark}")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

export HOME="$work/home" XDG_RUNTIME_DIR="$work/runtime" XDG_CONFIG_HOME="$work/config"
export XDG_CACHE_HOME="$work/cache" XDG_DATA_HOME="$work/data" XDG_STATE_HOME="$work/state"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
unset DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME/ryoku"
chmod 700 "$XDG_RUNTIME_DIR"
ln -s "$plugin/content" "$work/content"
cp "$here/ticker.qml" "$work/shell.qml"
if ! timeout 25 qs -p "$work/shell.qml" > "$work/log" 2>&1 ||
    ! grep -Fq 'CRATE-MARK-TICKER-PASS' "$work/log"; then
    cat "$work/log" >&2
    exit 1
fi
echo 'crate-mark ticker passed'
