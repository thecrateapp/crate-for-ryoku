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

Standard library only. The Chrome .crx is packed separately (apps/chrome/pack.sh)
because it needs the private key, which never enters this repository.
"""
import base64
import json
import os
import re
import shutil
import sys
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
    import hashlib
    digest = hashlib.sha256(base64.b64decode(public_key_b64)).hexdigest()[:32]
    return "".join(chr(ord("a") + int(c, 16)) for c in digest)


def main(argv):
    if len(argv) != 2 or argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if len(argv) == 2 else 2
    out = os.path.abspath(argv[1])
    print("obsidian", build_obsidian(out))
    xpi, chrome = build_firefox(out)
    print("firefox ", xpi)
    print("firefox ", chrome)
    unpacked, webstore = build_chrome(out)
    key = json.loads(read(os.path.join(unpacked, "manifest.json")))["key"]
    print("chrome  ", unpacked, f"(id {chrome_id(key)})")
    print("chrome  ", webstore)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
