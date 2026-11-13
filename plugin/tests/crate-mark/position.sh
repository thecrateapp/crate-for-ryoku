#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
plugin=$(realpath "${1:-$here/../../crate-mark}")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
unset DISPLAY WAYLAND_DISPLAY NIRI_SOCKET SWAYSOCK DBUS_SESSION_BUS_ADDRESS
mkdir -m 700 "$work"/{runtime,config,data,cache,state,home}
export HOME="$work/home" XDG_RUNTIME_DIR="$work/runtime" XDG_CONFIG_HOME="$work/config"
export XDG_DATA_HOME="$work/data" XDG_CACHE_HOME="$work/cache" XDG_STATE_HOME="$work/state"
export DBUS_SYSTEM_BUS_ADDRESS="unix:path=$work/runtime/no-system-bus"
export QT_QPA_PLATFORM=offscreen PLUGIN_DIR="$plugin"
ln -s "$plugin/content" "$work/content"
cp "$here/position.qml" "$work/shell.qml"
cd "$work"
dbus-run-session -- bash -eu -o pipefail -c '
    for peer in crate:0 other:329000000 paused:42250000; do
        name=${peer%:*}
        python3 "$1/position-peer.py" "org.mpris.MediaPlayer2.$name" "${peer#*:}" >"$name.log" &
        pids+=" $!"
    done
    trap "kill $pids 2>/dev/null || true" EXIT
    for name in crate other paused; do
        for i in {1..60}; do grep -q ready "$name.log" && break; sleep .05; done
        grep -q ready "$name.log"
    done
    timeout 20 qs -p shell.qml >log 2>&1 &
    test_pid=$!
    for i in {1..160}; do
        grep -q CRATE-MARK-SIMULATE-SEEK log && { touch seek; break; }
        if ! kill -0 "$test_pid" 2>/dev/null; then break; fi
        sleep .05
    done
    wait "$test_pid"
    if ! grep -q CRATE-MARK-POSITION-PASS log; then cat log >&2; exit 1; fi
' bash "$here"
echo "crate-mark raw playback position passed"
