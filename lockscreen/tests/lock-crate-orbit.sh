#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config" "$tmp/runtime" "$tmp/data" "$tmp/cache"
chmod 700 "$tmp/runtime"
# Every skin runs the same checks (harness/SkinChecks.js).
for skin in crate/orbit; do
    out="$tmp/output-${skin//\//-}"
    SKIN="$skin" LOCK_ROOT="$(cd "$here/.." && pwd)" \
    XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" \
    QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 \
    QML_IMPORT_PATH="$here/harness/imports" QML2_IMPORT_PATH="$here/harness/imports" \
        timeout "${LOCK_TEST_TIMEOUT:-15s}" qs -p "$here/lock-crate-orbit.qml" > "$out" 2>&1 || { cat "$out"; exit 1; }
    if grep -q 'FAIL:\|QQmlComponent\|Error\|qml\[-\?[0-9]*:' "$out" || ! grep -q 'PASS:' "$out"; then
        cat "$out"
        exit 1
    fi
    grep 'PASS:' "$out"
done
