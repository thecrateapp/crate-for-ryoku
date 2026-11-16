#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# SDDM must never load Mpris: only NowPlayingMpris.qml may import it.
if grep -rl 'Services.Mpris' "$here/../crate" | grep -v '/common/NowPlayingMpris.qml$' | grep -q .; then
    echo "FAIL: a file other than NowPlayingMpris.qml imports Services.Mpris"
    exit 1
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config" "$tmp/runtime" "$tmp/data" "$tmp/cache"
chmod 700 "$tmp/runtime"
out="$tmp/output"
LOCK_ROOT="$(cd "$here/.." && pwd)" \
XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" \
QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 \
QML_IMPORT_PATH="$here/harness/imports" QML2_IMPORT_PATH="$here/harness/imports" \
    timeout 15s qs -p "$here/lock-crate-nowplaying.qml" > "$out" 2>&1 || { cat "$out"; exit 1; }
if grep -q 'FAIL:\|QQmlComponent\|Error\|qml\[-\?[0-9]*:' "$out" || ! grep -q 'PASS:' "$out"; then
    cat "$out"
    exit 1
fi
grep 'PASS:' "$out"
