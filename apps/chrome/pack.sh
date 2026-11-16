#!/usr/bin/env bash
# Pack the Chrome theme into a signed .crx with the theme's private key, for the
# crate-for-ryoku-chrome-theme package (external_crx install) and for a first
# Web Store upload that keeps the same id. The key never enters the repository:
# CRATE_CHROME_KEY names it (default ~/.local/share/crate-signing-keys/
# crate-chrome-theme.pem). Writes OUT/crate-theme-VERSION.crx (default dist/).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../.." && pwd)
key=${CRATE_CHROME_KEY:-$HOME/.local/share/crate-signing-keys/crate-chrome-theme.pem}
out=${1:-$root/dist}
[ -f "$key" ] || { echo "pack.sh: no private key at $key (set CRATE_CHROME_KEY)" >&2; exit 1; }
chrome=$(command -v google-chrome-stable || command -v google-chrome || command -v chromium || true)
[ -n "$chrome" ] || { echo "pack.sh: needs google-chrome or chromium to pack" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
python3 "$root/apps/build.py" "$work/build" >/dev/null
version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$work/build/chrome/crate-theme/manifest.json")
# the key in the manifest must be this private key's public half, or the id moves
want=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["key"])' "$work/build/chrome/crate-theme/manifest.json")
have=$(openssl pkey -in "$key" -pubout -outform DER | base64 -w0)
[ "$want" = "$have" ] || { echo "pack.sh: $key does not match the manifest key" >&2; exit 1; }
"$chrome" --headless=new --user-data-dir="$work/profile" --password-store=basic \
  --pack-extension="$work/build/chrome/crate-theme" --pack-extension-key="$key" >/dev/null 2>&1 || true
[ -s "$work/build/chrome/crate-theme.crx" ] || { echo "pack.sh: chrome did not write a .crx" >&2; exit 1; }
mkdir -p "$out"
install -m644 "$work/build/chrome/crate-theme.crx" "$out/crate-theme-$version.crx"
cp "$work/build/chrome/crate-theme-$version-webstore.zip" "$out/"
echo "packed $out/crate-theme-$version.crx"
echo "       $out/crate-theme-$version-webstore.zip (Web Store upload, no key)"
