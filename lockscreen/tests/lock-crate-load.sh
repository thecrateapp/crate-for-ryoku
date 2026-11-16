#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config" "$tmp/runtime" "$tmp/data" "$tmp/cache"
chmod 700 "$tmp/runtime"
imports="$here/harness/imports"
LOCK_ROOT="$(cd "$here/.." && pwd)" \
XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" \
QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 \
QML_IMPORT_PATH="$imports:${QML_IMPORT_PATH:-}" QML2_IMPORT_PATH="$imports:${QML2_IMPORT_PATH:-}" \
    timeout 15s qs -p "$here/lock-crate-load.qml" > "$tmp/output" 2>&1 || {
        cat "$tmp/output"
        exit 1
    }
if grep -q 'FAIL:\|QQmlComponent\|Error\|qml\[-\?[0-9]*:' "$tmp/output" || ! grep -q 'PASS:' "$tmp/output"; then
    cat "$tmp/output"
    exit 1
fi
grep 'PASS:' "$tmp/output"
