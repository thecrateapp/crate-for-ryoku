#!/usr/bin/env bash
# Pack the Chrome theme into a signed .crx with the theme's private key, for a
# release asset or a first Web Store upload that keeps the same id (the package
# build packs its own: package/build-chrome.sh). The key never enters the
# repository: CRATE_CHROME_KEY names it (default ~/.local/share/crate-signing-keys/
# crate-chrome-theme.pem). Writes OUT/crate-theme-VERSION.crx and the Web Store
# zip (default dist/).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../.." && pwd)
key=${CRATE_CHROME_KEY:-$HOME/.local/share/crate-signing-keys/crate-chrome-theme.pem}
out=${1:-$root/dist}
[ -f "$key" ] || { echo "pack.sh: no private key at $key (set CRATE_CHROME_KEY)" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
# build.py signs the CRX3 with openssl, refuses a key that is not the manifest's
# and checks the packed id; no browser is needed
python3 "$root/apps/build.py" "$work/build" --chrome-key "$key" >/dev/null
crx=$(ls "$work"/build/chrome/crate-theme-*.crx)
mkdir -p "$out"
install -m644 "$crx" "$out/"
cp "$work"/build/chrome/crate-theme-*-webstore.zip "$out/"
echo "packed $out/$(basename "$crx")"
echo "       $out/$(basename "$work"/build/chrome/crate-theme-*-webstore.zip) (Web Store upload, no key)"
