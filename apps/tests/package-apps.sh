#!/usr/bin/env bash
# The Chrome theme in the package: build-chrome.sh packs a signed .crx and its
# external-extension file when the key is there and steps aside cleanly when it
# is not, and the PKGBUILD lays both where Chrome and Chromium look. A
# throwaway key signs a throwaway copy of the theme: the real key is never read,
# nothing is installed outside temp dirs, and no browser runs.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
real_id=jddiejdibphncbpfehopofclalbeghbc

# a copy of what build-chrome.sh reads, with the manifest key swapped for a throwaway one
mini="$tmp/repo"
mkdir -p "$mini/package" "$mini/plugin/crate-mark/content" "$mini/theme"
cp -a "$repo/apps" "$mini/apps"
cp -a "$repo/plugin/crate-mark/content/fonts" "$mini/plugin/crate-mark/content/fonts"
cp -a "$repo/theme/fonts" "$mini/theme/fonts"
cp "$repo/package/build-chrome.sh" "$mini/package/"
key="$tmp/throwaway.pem"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$key" 2>/dev/null
want=$(python3 - "$mini/apps/chrome/theme/manifest.json" "$key" "$repo/apps" <<'PY'
import base64, json, subprocess, sys
path, key, apps = sys.argv[1:]
sys.path.insert(0, apps)
import build
m = json.load(open(path))
m["key"] = base64.b64encode(subprocess.run(["openssl", "pkey", "-in", key, "-pubout", "-outform", "DER"],
                                           capture_output=True, check=True).stdout).decode()
json.dump(m, open(path, "w"), indent=2)
print(build.chrome_id(m["key"]))
PY
)
[ "$want" != "$real_id" ] || fail "the throwaway key has the real id"

# 1. with a key: the .crx carries the key's id and the json is named after it
out="$tmp/dist/chrome"
CRATE_CHROME_KEY="$key" bash "$mini/package/build-chrome.sh" "$out" > "$tmp/build.log" 2>&1 \
    || { cat "$tmp/build.log"; fail "build-chrome.sh failed with a key"; }
[ -s "$out/crate-theme.crx" ] || fail "no crate-theme.crx"
got=$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import build; print(build.verify_crx(sys.argv[2]))' \
    "$repo/apps" "$out/crate-theme.crx") || fail "the .crx does not verify"
[ "$got" = "$want" ] || fail "crx id $got, want $want"
python3 - "$out/$want.json" <<'PY' || fail "$want.json is not the external-extension file"
import json, sys
assert json.load(open(sys.argv[1])) == {"external_crx": "/usr/share/crate-for-ryoku/chrome/crate-theme.crx",
                                        "external_version": "1.0.0"}
PY

# 2. a key that is not the manifest's fails the build (the id would move)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$tmp/other.pem" 2>/dev/null
if CRATE_CHROME_KEY="$tmp/other.pem" bash "$mini/package/build-chrome.sh" "$tmp/other" > "$tmp/other.log" 2>&1; then
    fail "build-chrome.sh packed with a key that is not the manifest's"
fi
grep -q "not the key in the Chrome manifest" "$tmp/other.log" || { cat "$tmp/other.log"; fail "no mismatch message"; }
[ ! -e "$tmp/other/crate-theme.crx" ] || fail "a .crx was written with the wrong key"

# 3. no key (CI, the AUR): a warning, nothing packed, and the build goes on
CRATE_CHROME_KEY="$tmp/missing.pem" bash "$repo/package/build-chrome.sh" "$tmp/nokey" > "$tmp/nokey.log" 2>&1 \
    || { cat "$tmp/nokey.log"; fail "build-chrome.sh failed without a key"; }
grep -q "ships without the Chrome theme" "$tmp/nokey.log" || fail "no warning without a key"
[ ! -e "$tmp/nokey" ] || fail "build-chrome.sh wrote files without a key"
grep -qF 'bash "$SRC/package/build-chrome.sh" "$OUT/chrome"' "$repo/package/build.sh" || fail "build.sh does not run build-chrome.sh"

# 4. the PKGBUILD's package() on a fake dist: the .crx under /usr/share/crate-for-ryoku/chrome and
# the json in both browsers' folders; without the .crx, neither
pkgbuild="$repo/packaging/aur/crate-for-ryoku/PKGBUILD"
grep -q "^_chrome_id=$real_id" "$pkgbuild" || fail "PKGBUILD _chrome_id is not $real_id"
ver=$(sed -n 's/^pkgver=//p' "$pkgbuild")
run_package() { # $1: srcdir holding the checkout, $2: pkgdir
    (set -e; source "$pkgbuild"; srcdir=$1; pkgdir=$2; cd "$srcdir"; package)
}
fake() { # $1: srcdir, $2: 1 to include the Chrome theme
    local d="$1/crate-for-ryoku"
    mkdir -p "$d/dist/crate-for-ryoku-$ver/bin"
    : > "$d/dist/crate-for-ryoku-$ver/bin/crate-for-ryoku"
    cp "$repo/LICENSE" "$repo/NOTICE" "$d/"
    if [ "$2" = 1 ]; then
        mkdir -p "$d/dist/crate-for-ryoku-$ver/chrome"
        cp "$out/crate-theme.crx" "$d/dist/crate-for-ryoku-$ver/chrome/"
        cp "$out/$want.json" "$d/dist/crate-for-ryoku-$ver/chrome/$real_id.json"
    fi
    mkdir -p "$d/dist/crate-for-ryoku-$ver/boot/plymouth/crate" "$d/dist/crate-for-ryoku-$ver/boot/refind/crate"
    : > "$d/dist/crate-for-ryoku-$ver/boot/plymouth/crate/crate.plymouth"
    : > "$d/dist/crate-for-ryoku-$ver/boot/refind/crate/theme.conf"
}
fake "$tmp/src1" 1
run_package "$tmp/src1" "$tmp/pkg1" || fail "package() failed with the Chrome theme"
for f in usr/share/crate-for-ryoku/chrome/crate-theme.crx "usr/share/google-chrome/extensions/$real_id.json" \
         "usr/share/chromium/extensions/$real_id.json"; do
    [ -s "$tmp/pkg1/$f" ] || fail "package() did not install /$f"
done
for f in usr/share/plymouth/themes/crate/crate.plymouth usr/share/crate-for-ryoku/boot/refind/crate/theme.conf; do
    [ -e "$tmp/pkg1/$f" ] || fail "package() did not install the boot theme /$f"
done
crx=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["external_crx"])' \
    "$tmp/pkg1/usr/share/google-chrome/extensions/$real_id.json")
[ -s "$tmp/pkg1$crx" ] || fail "external_crx $crx is not in the package"
# apps.sh status sees the package's files
status=$(env -i HOME="$tmp/home" PATH="/usr/bin:/bin" CRATE_SYSTEM_ROOT="$tmp/pkg1" CRATE_APPS_DIR="$tmp" \
    bash "$repo/package/apps.sh" status)
echo "$status" | grep -qE "Chrome .*(offered by the package|Crate theme packaged)" \
    || fail "apps.sh status does not see the packaged theme: $status"
fake "$tmp/src2" 0
run_package "$tmp/src2" "$tmp/pkg2" || fail "package() failed without the Chrome theme"
[ ! -e "$tmp/pkg2/usr/share/google-chrome" ] && [ ! -e "$tmp/pkg2/usr/share/chromium" ] \
    || fail "package() installed an external-extension file without the .crx"

# 5. the committed .SRCINFO is what makepkg prints for the PKGBUILD (makepkg refuses root: CI's
# container skips the comparison and checks the committed file alone)
srcinfo_file="$(dirname "$pkgbuild")/.SRCINFO"
grep -q "makedepends = openssl" "$srcinfo_file" || fail ".SRCINFO lacks openssl"
if grep -q "chrome-theme" "$srcinfo_file"; then fail ".SRCINFO names crate-for-ryoku-chrome-theme"; fi
if [ "$(id -u)" != 0 ] && command -v makepkg >/dev/null; then
    (cd "$(dirname "$pkgbuild")" && makepkg --printsrcinfo) > "$tmp/srcinfo" || fail "makepkg --printsrcinfo failed"
    diff -u "$srcinfo_file" "$tmp/srcinfo" || fail ".SRCINFO is stale: makepkg --printsrcinfo > .SRCINFO"
else
    echo "skip: makepkg --printsrcinfo (root or no makepkg)"
fi
[ ! -e "$repo/packaging/aur/crate-for-ryoku-chrome-theme" ] || fail "the separate Chrome package is still there"
echo "PASS: package-apps"
