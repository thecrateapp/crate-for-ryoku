#!/usr/bin/env bash
# crate-mark's title ticker rests after two rolls and rolls again on a new title.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/runtime" && chmod 700 "$work/runtime"
cp "$here/../../crate-mark/content/TrackTicker.qml" "$work/"
cp "$here/ticker-rest.qml" "$work/shell.qml"
env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u HYPRLAND_INSTANCE_SIGNATURE \
  QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$work/runtime" timeout 40 qs -p "$work/shell.qml" >"$work/log" 2>&1 || true
if ! grep -q TICKER-PROBE-PASS "$work/log"; then
    echo "ticker-rest: FAILED" >&2; sed -n '1,40p' "$work/log" >&2; exit 1
fi
echo "ticker-rest: rolls, rests after two rolls, rolls again on a new title"
