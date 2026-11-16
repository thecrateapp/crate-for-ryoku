#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config" "$tmp/runtime" "$tmp/data" "$tmp/cache"
chmod 700 "$tmp/runtime"
# run <label> <import path> <SDDM_ONLY> [NO_TOKENS]. Qt always searches the system path, so a real Ryoku install stays visible; SDDM never links it, and the notokens run shadows it with a broken module.
run() {
    local out="$tmp/output-$1"
    LOCK_ROOT="$(cd "$here/.." && pwd)" SDDM_ONLY="$3" NO_TOKENS="${4:-0}" \
    XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" \
    QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 \
    QML_IMPORT_PATH="$2" QML2_IMPORT_PATH="$2" \
        timeout 15s qs -p "$here/lock-crate-load.qml" > "$out" 2>&1 || { cat "$out"; exit 1; }
    if grep -q 'FAIL:\|QQmlComponent\|Error\|qml\[-\?[0-9]*:' "$out" || ! grep -q 'PASS:' "$out"; then
        cat "$out"
        exit 1
    fi
    grep 'PASS:' "$out"
}
run lock "$here/harness/imports" 0
run sddm "" 1
# A Ryoku module whose Tokens cannot load (a system install would otherwise be found).
run notokens "$here/harness/imports-broken" 0 1
