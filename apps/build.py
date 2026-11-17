#!/usr/bin/env python3
"""Build Crate's app themes from apps/ into OUT (run: python3 apps/build.py OUT).

  OUT/obsidian/Crate/            theme.css (fonts inlined) + manifest.json, the
                                 folder a vault's .obsidian/themes/ takes
  OUT/firefox/crate-theme-V.xpi  the Firefox theme add-on, unsigned (AMO signs it)
  OUT/firefox/chrome/            userChrome.css, userContent.css and their fonts,
                                 the opt-in layer for a Firefox profile
  OUT/chrome/crate-theme/        the Chrome theme, unpacked, with its fixed key
  OUT/chrome/crate-theme-V-webstore.zip
                                 the same without "key", for the Chrome Web Store
  OUT/chrome/crate-theme-V.crx   with --chrome-key KEY only: the Chrome theme
                                 packed and signed (CRX3) with the theme's
                                 private key, whose public half the manifest
                                 carries, so its id stays fixed

Standard library only, plus the openssl command for the .crx signature. The
private key never enters this repository (package/build-chrome.sh says where
it lives).
"""
import base64
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

APPS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(APPS)

# the woff2 files the themes embed or ship, by the name the sources use
FONTS = {
    "roboto-latin": os.path.join(ROOT, "plugin/crate-mark/content/fonts/roboto-latin.woff2"),
    "bricolage-grotesque-latin": os.path.join(ROOT, "theme/fonts/bricolage-grotesque-latin-opsz-normal.woff2"),
    "jetbrains-mono-latin": os.path.join(APPS, "fonts/jetbrains-mono-latin-400-normal.woff2"),
}
FONT_LICENCES = {
    "OFL-roboto.txt": os.path.join(ROOT, "plugin/crate-mark/content/fonts/Roboto-OFL.txt"),
    "OFL-bricolage-grotesque.txt": os.path.join(ROOT, "theme/fonts/OFL.txt"),
    "OFL-jetbrains-mono.txt": os.path.join(APPS, "fonts/OFL-jetbrains-mono.txt"),
}
FONT_URL = re.compile(r'url\("crate-font:([a-z0-9-]+)"\)')

# zip entries get a fixed time so two builds of the same sources are identical
ZIP_TIME = (2026, 1, 1, 0, 0, 0)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def inline_fonts(css):
    """Replace each url("crate-font:NAME") with the font as a data URL."""
    def data_url(m):
        name = m.group(1)
        if name not in FONTS:
            raise SystemExit(f"apps/build.py: unknown font {name}")
        with open(FONTS[name], "rb") as f:
            b64 = base64.b64encode(f.read()).decode("ascii")
        return f'url("data:font/woff2;base64,{b64}")'
    return FONT_URL.sub(data_url, css)


def zip_dir(src, dest, transform=None):
    """Zip src's files (sorted, fixed times) into dest; transform(rel, bytes)
    may rewrite a file's contents."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for base, _, files in sorted(os.walk(src)):
            for name in sorted(files):
                path = os.path.join(base, name)
                rel = os.path.relpath(path, src)
                with open(path, "rb") as f:
                    data = f.read()
                if transform:
                    data = transform(rel, data)
                info = zipfile.ZipInfo(rel, ZIP_TIME)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o644 << 16
                z.writestr(info, data)


def build_obsidian(out):
    dest = os.path.join(out, "obsidian", "Crate")
    write(os.path.join(dest, "theme.css"), inline_fonts(read(os.path.join(APPS, "obsidian/theme.css"))))
    shutil.copyfile(os.path.join(APPS, "obsidian/manifest.json"), os.path.join(dest, "manifest.json"))
    return dest


def build_firefox(out):
    src = os.path.join(APPS, "firefox/theme")
    version = json.loads(read(os.path.join(src, "manifest.json")))["version"]
    xpi = os.path.join(out, "firefox", f"crate-theme-{version}.xpi")
    zip_dir(src, xpi)
    chrome = os.path.join(out, "firefox", "chrome")
    os.makedirs(os.path.join(chrome, "fonts"), exist_ok=True)
    for name in ("userChrome.css", "userContent.css"):
        shutil.copyfile(os.path.join(APPS, "firefox/chrome", name), os.path.join(chrome, name))
    for name, path in FONTS.items():
        shutil.copyfile(path, os.path.join(chrome, "fonts", os.path.basename(path)))
    for name, path in FONT_LICENCES.items():
        shutil.copyfile(path, os.path.join(chrome, "fonts", name))
    return xpi, chrome


def build_zed(out):
    dest = os.path.join(out, "zed", "crate.json")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copyfile(os.path.join(APPS, "zed/crate.json"), dest)
    return dest


def build_lazygit(out):
    dest = os.path.join(out, "lazygit", "config.yml")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copyfile(os.path.join(APPS, "lazygit/config.yml"), dest)
    return dest


def build_nvim(out):
    dest = os.path.join(out, "nvim", "crate.lua")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copyfile(os.path.join(APPS, "nvim/crate.lua"), dest)
    return dest


def build_gtk(out):
    dest = os.path.join(out, "gtk", "crate.css")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copyfile(os.path.join(APPS, "gtk/crate.css"), dest)
    shutil.copyfile(os.path.join(APPS, "gtk/crate-gtk3.css"), os.path.join(os.path.dirname(dest), "crate-gtk3.css"))
    return dest


def build_gtksourceview(out):
    dest = os.path.join(out, "gtksourceview", "crate.xml")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copyfile(os.path.join(APPS, "gtksourceview/crate.xml"), dest)
    return dest


def build_chrome(out):
    src = os.path.join(APPS, "chrome/theme")
    manifest = json.loads(read(os.path.join(src, "manifest.json")))
    unpacked = os.path.join(out, "chrome", "crate-theme")
    if os.path.isdir(unpacked):
        shutil.rmtree(unpacked)
    shutil.copytree(src, unpacked)

    def drop_key(rel, data):
        # the Web Store refuses a manifest with "key"; it keeps the item's own
        if rel != "manifest.json":
            return data
        m = json.loads(data)
        m.pop("key", None)
        return (json.dumps(m, indent=2) + "\n").encode()

    webstore = os.path.join(out, "chrome", f"crate-theme-{manifest['version']}-webstore.zip")
    zip_dir(src, webstore, drop_key)
    return unpacked, webstore


def chrome_id(public_key_b64):
    """The extension id Chrome derives from a manifest "key"."""
    return crx_id_of_der(base64.b64decode(public_key_b64))


def crx_id_of_der(public_key_der):
    """The extension id of a DER SubjectPublicKeyInfo: its SHA-256, first 16
    bytes, each nibble written as a letter a..p."""
    digest = hashlib.sha256(public_key_der).hexdigest()[:32]
    return "".join(chr(ord("a") + int(c, 16)) for c in digest)


# ---------- CRX3 ----------
# A .crx (version 3) is "Cr24", the format version, a protobuf CrxFileHeader and
# the zip. The header holds the public key and an RSA SHA-256 signature over
# "CRX3 SignedData\0", the length of the signed header data, that data (a
# SignedData with the 16-byte crx id) and the zip
# (chromium/src/components/crx_file/crx3.proto).

CRX_MAGIC = b"Cr24"
CRX_SIGNED_DATA = b"CRX3 SignedData\x00"


def _varint(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def _field(number, payload):
    """A length-delimited protobuf field."""
    return _varint(number << 3 | 2) + _varint(len(payload)) + payload


def _fields(data):
    """The length-delimited fields of a protobuf message, as (number, bytes)."""
    i, out = 0, []
    while i < len(data):
        key = shift = 0
        while True:
            b = data[i]
            i += 1
            key |= (b & 0x7F) << shift
            shift += 7
            if not b & 0x80:
                break
        if key & 7 != 2:
            raise ValueError("crx header: unexpected wire type %d" % (key & 7))
        size = shift = 0
        while True:
            b = data[i]
            i += 1
            size |= (b & 0x7F) << shift
            shift += 7
            if not b & 0x80:
                break
        out.append((key >> 3, data[i:i + size]))
        i += size
    return out


def _openssl(*args, data=None):
    try:
        r = subprocess.run(["openssl", *args], input=data, capture_output=True, check=False)
    except FileNotFoundError:
        raise SystemExit("apps/build.py: packing the .crx needs the openssl command")
    if r.returncode != 0:
        raise SystemExit("apps/build.py: openssl %s failed: %s" % (args[0], r.stderr.decode(errors="replace").strip()))
    return r.stdout


def public_key_der(key_path):
    """The DER SubjectPublicKeyInfo of a PEM private key."""
    return _openssl("pkey", "-in", key_path, "-pubout", "-outform", "DER")


def pack_crx(src, key_path, dest):
    """Zip src and sign it into a CRX3 at dest with the RSA key at key_path;
    returns the extension id."""
    pub = public_key_der(key_path)
    with tempfile.TemporaryDirectory() as tmp:
        archive = os.path.join(tmp, "theme.zip")
        zip_dir(src, archive)
        with open(archive, "rb") as f:
            zipped = f.read()
        signed_header = _field(1, hashlib.sha256(pub).digest()[:16])
        message = CRX_SIGNED_DATA + struct.pack("<I", len(signed_header)) + signed_header + zipped
        payload = os.path.join(tmp, "signed")
        with open(payload, "wb") as f:
            f.write(message)
        signature = _openssl("dgst", "-sha256", "-sign", key_path, payload)
    header = _field(2, _field(1, pub) + _field(2, signature)) + _field(10000, signed_header)
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    with open(dest, "wb") as f:
        f.write(CRX_MAGIC + struct.pack("<II", 3, len(header)) + header + zipped)
    return crx_id_of_der(pub)


def read_crx(path):
    """A CRX3's parts: {"id", "public_keys", "proofs" [(key, signature)],
    "signed_data" (the bytes signed before the zip), "zip"}."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != CRX_MAGIC:
        raise ValueError("%s is not a .crx" % path)
    version, size = struct.unpack("<II", data[4:12])
    if version != 3:
        raise ValueError("%s is CRX%d, not CRX3" % (path, version))
    header, zipped = data[12:12 + size], data[12 + size:]
    proofs, signed_header = [], b""
    for number, value in _fields(header):
        if number == 2:
            parts = dict(_fields(value))
            proofs.append((parts.get(1, b""), parts.get(2, b"")))
        elif number == 10000:
            signed_header = value
    crx_id = dict(_fields(signed_header)).get(1, b"")
    # the id the header declares must be one of its keys' own
    matching = [k for k, _ in proofs if hashlib.sha256(k).digest()[:16] == crx_id]
    if not matching:
        raise ValueError("%s: no key in the header matches its crx id" % path)
    return {
        "id": crx_id_of_der(matching[0]),
        "proofs": proofs,
        "signed_data": CRX_SIGNED_DATA + struct.pack("<I", len(signed_header)) + signed_header,
        "zip": zipped,
    }


def verify_crx(path):
    """Check every signature in a CRX3 with openssl; returns its id."""
    crx = read_crx(path)
    with tempfile.TemporaryDirectory() as tmp:
        payload = os.path.join(tmp, "signed")
        with open(payload, "wb") as f:
            f.write(crx["signed_data"] + crx["zip"])
        for i, (key, signature) in enumerate(crx["proofs"]):
            pem = os.path.join(tmp, "key%d.pem" % i)
            sig = os.path.join(tmp, "sig%d" % i)
            with open(sig, "wb") as f:
                f.write(signature)
            _openssl("pkey", "-pubin", "-inform", "DER", "-out", pem, data=key)
            _openssl("dgst", "-sha256", "-verify", pem, "-signature", sig, payload)
    return crx["id"]


def build_crx(out, key_path):
    """Pack OUT/chrome/crate-theme/ into OUT/chrome/crate-theme-V.crx, refusing
    a key whose public half is not the manifest's (the id would move)."""
    unpacked = os.path.join(out, "chrome", "crate-theme")
    manifest = json.loads(read(os.path.join(unpacked, "manifest.json")))
    if base64.b64decode(manifest["key"]) != public_key_der(key_path):
        raise SystemExit(f"apps/build.py: {key_path} is not the key in the Chrome manifest")
    crx = os.path.join(out, "chrome", f"crate-theme-{manifest['version']}.crx")
    crx_id = pack_crx(unpacked, key_path, crx)
    if crx_id != chrome_id(manifest["key"]) or verify_crx(crx) != crx_id:
        raise SystemExit(f"apps/build.py: {crx} does not carry the manifest's id")
    return crx, crx_id


def main(argv):
    args, chrome_key = list(argv[1:]), None
    if "--chrome-key" in args:
        i = args.index("--chrome-key")
        if i + 1 >= len(args):
            print("apps/build.py: --chrome-key needs a key file", file=sys.stderr)
            return 2
        chrome_key = args.pop(i + 1)
        args.pop(i)
    if len(args) != 1 or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if args in (["-h"], ["--help"]) else 2
    out = os.path.abspath(args[0])
    print("obsidian", build_obsidian(out))
    xpi, chrome = build_firefox(out)
    print("firefox ", xpi)
    print("firefox ", chrome)
    print("zed     ", build_zed(out))
    print("lazygit ", build_lazygit(out))
    print("nvim    ", build_nvim(out))
    print("gtk     ", build_gtk(out))
    print("source  ", build_gtksourceview(out))
    unpacked, webstore = build_chrome(out)
    key = json.loads(read(os.path.join(unpacked, "manifest.json")))["key"]
    print("chrome  ", unpacked, f"(id {chrome_id(key)})")
    print("chrome  ", webstore)
    if chrome_key:
        crx, crx_id = build_crx(out, chrome_key)
        print("chrome  ", crx, f"(id {crx_id})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
