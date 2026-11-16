#!/usr/bin/env bash
# Preview a Crate lock skin without locking anything. Windowed by default; --shot renders offscreen.
#   preview.sh <crate/hero|crate/orbit> [state] [--shot out.png] [--size WxH]
# States: idle typing checking error fp-scanning fp-success fp-fail key-pin key-touch no-music sddm
# Uses the test fakes (tests/harness) in a plain window: it never creates a session lock.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
skins="crate/hero crate/orbit"
states="idle typing checking error fp-scanning fp-success fp-fail key-pin key-touch no-music sddm"
usage() {
    echo "usage: preview.sh <crate/hero|crate/orbit> [${states// /|}] [--shot out.png] [--size WxH]" >&2
    exit 2
}
[ $# -ge 1 ] || usage
skin="$1"; shift
state=idle; shot=""; size="1920x1200"
if [ $# -gt 0 ] && [[ "$1" != --* ]]; then state="$1"; shift; fi
while [ $# -gt 0 ]; do
    case "$1" in
        --shot) [ $# -ge 2 ] || usage; shot="$2"; shift 2 ;;
        --size) [ $# -ge 2 ] || usage; size="$2"; shift 2 ;;
        *) usage ;;
    esac
done
[[ " $skins " == *" $skin "* ]] || usage
[[ " $states " == *" $state "* ]] || usage
[[ "$size" =~ ^[0-9]+x[0-9]+$ ]] || usage

if [ ! -d "$here/crate/common/fonts" ] || [ ! -d "$here/crate/common/backgrounds" ]; then
    bash "$here/build-assets.sh"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config" "$tmp/runtime" "$tmp/data" "$tmp/cache"
chmod 700 "$tmp/runtime"
harness="$here/tests/harness"
export PV_LOCK_ROOT="$here" PV_SKIN="$skin" PV_STATE="$state" PV_SIZE="$size" PV_SHOT="$shot"
export XDG_CONFIG_HOME="$tmp/config" XDG_DATA_HOME="$tmp/data" XDG_CACHE_HOME="$tmp/cache"
export QML_XHR_ALLOW_FILE_READ=1 QML_IMPORT_PATH="$harness/imports" QML2_IMPORT_PATH="$harness/imports"

if [ -z "$shot" ]; then
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$tmp/runtime}"
    exec qs -p "$harness/Preview.qml"
fi

mkdir -p "$(dirname "$shot")"
export XDG_RUNTIME_DIR="$tmp/runtime" QT_QPA_PLATFORM=offscreen
rc=0
timeout 30s qs -p "$harness/Preview.qml" > "$tmp/out" 2>&1 || rc=$?
cat "$tmp/out"
if [ "$rc" -ne 0 ] || grep -q 'PREVIEW ERROR\|QQmlComponent\|Error\|qml\[-\?[0-9]*:\|ReferenceError\|TypeError' "$tmp/out" || [ ! -s "$shot" ]; then
    echo "preview.sh: failed to render $skin $state" >&2
    exit 1
fi
