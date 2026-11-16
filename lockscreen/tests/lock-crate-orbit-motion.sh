#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config" "$tmp/runtime" "$tmp/data" "$tmp/cache"
chmod 700 "$tmp/runtime"
lock_root="$(cd "$here/.." && pwd)"
fail() { echo "FAIL: $*"; exit 1; }

# The lock shell holds the surface for these keys after an unlock (orbit only; hero keeps the
# shell's default).
grep -q '^unlockRevealMs=[0-9]\+$' "$lock_root/crate/orbit/theme.conf" || fail "orbit theme.conf has no unlockRevealMs"
grep -q '^unlockSensorRevealMs=[0-9]\+$' "$lock_root/crate/orbit/theme.conf" || fail "orbit theme.conf has no unlockSensorRevealMs"
if grep -q '^unlock' "$lock_root/crate/hero/theme.conf"; then fail "hero theme.conf must not hold the unlock surface"; fi

out="$tmp/output"
THEME_CONF="$(cat "$lock_root/crate/orbit/theme.conf")" LOCK_ROOT="$lock_root" \
XDG_RUNTIME_DIR="$tmp/runtime" XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache" \
QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 \
QML_IMPORT_PATH="$here/harness/imports" QML2_IMPORT_PATH="$here/harness/imports" \
    timeout "${LOCK_TEST_TIMEOUT:-20s}" qs -p "$here/lock-crate-orbit-motion.qml" > "$out" 2>&1 || { cat "$out"; exit 1; }
if grep -q 'FAIL:\|QQmlComponent\|Error\|qml\[-\?[0-9]*:' "$out" || ! grep -q 'PASS:' "$out"; then
    cat "$out"
    exit 1
fi
grep 'PASS:' "$out"
