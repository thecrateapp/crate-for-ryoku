#!/usr/bin/env bash
# Pack the Chrome theme for the package: DEST/crate-theme.crx, signed with the
# theme's private key, and DEST/<id>.json, the external-extension file the
# PKGBUILD installs for Google Chrome and Chromium (they then offer the theme
# once to every user). The key never enters the repository: CRATE_CHROME_KEY
# names it (default ~/.local/share/crate-signing-keys/crate-chrome-theme.pem).
# Without it nothing is packed and the build goes on: the package then ships
# without the Chrome theme (CI and AUR builds have no key).
#   build-chrome.sh DEST
set -euo pipefail
SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DEST=${1:?usage: build-chrome.sh DEST}
KEY=${CRATE_CHROME_KEY:-$HOME/.local/share/crate-signing-keys/crate-chrome-theme.pem}

if [ ! -f "$KEY" ]; then
  printf '\033[33m!!\033[0m %s\n' "build-chrome.sh: no Chrome signing key at $KEY; the package ships without the Chrome theme (set CRATE_CHROME_KEY)" >&2
  exit 0
fi
command -v openssl >/dev/null || { echo "build-chrome.sh: openssl is needed to sign the .crx" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
# build.py refuses a key that is not the manifest's and checks the packed id
python3 "$SRC/apps/build.py" "$work" --chrome-key "$KEY" >/dev/null
read -r version id < <(python3 -c 'import json, sys
sys.path.insert(0, sys.argv[1])
import build
m = json.load(open(sys.argv[2]))
print(m["version"], build.chrome_id(m["key"]))' "$SRC/apps" "$work/chrome/crate-theme/manifest.json")
mkdir -p "$DEST"
install -m644 "$work/chrome/crate-theme-$version.crx" "$DEST/crate-theme.crx"
# the browsers look for <id>.json; its external_crx is /usr/share/crate-for-ryoku/chrome/crate-theme.crx
sed "s/@VERSION@/$version/" "$SRC/apps/chrome/external/crx.json" > "$DEST/$id.json"
echo "packed $DEST/crate-theme.crx ($id, $version)"
