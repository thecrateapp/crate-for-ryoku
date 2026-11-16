#!/usr/bin/env bash
# preview.sh --shot renders every skin in every state offscreen, never creating a session lock.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
states="${STATES:-idle typing checking error fp-scanning fp-success fp-fail key-pin key-touch no-music sddm}"
size="1366x768"
fail() { echo "FAIL: $*"; exit 1; }

if grep -rq 'WlSessionLock' "$here/../preview.sh" "$here/harness/Preview.qml"; then
    fail "preview shell mentions WlSessionLock"
fi
rc=0; bash "$here/../preview.sh" crate/nope idle >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "unknown skin exited $rc, expected 2"
rc=0; bash "$here/../preview.sh" crate/hero nope >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] || fail "unknown state exited $rc, expected 2"

for skin in crate/hero crate/orbit; do
    for state in $states; do
        png="$tmp/${skin//\//-}-$state.png"
        bash "$here/../preview.sh" "$skin" "$state" --shot "$png" --size "$size" > "$tmp/log" 2>&1 \
            || { cat "$tmp/log"; fail "$skin $state: preview exited non-zero"; }
        [ -s "$png" ] || fail "$skin $state: no PNG"
        info="$(python3 - "$png" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
print(im.size[0], im.size[1], len(im.resize((96, 54)).getcolors(96*54)) > 8)
PY
)"
        [ "$info" = "1366 768 True" ] || fail "$skin $state: PNG is '$info', expected '1366 768 True'"
    done
done
echo "PASS: preview shots for 2 skins x $(echo $states | wc -w) states"
