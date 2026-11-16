#!/usr/bin/env python3
"""Build Crate's app themes from apps/ into OUT (run: python3 apps/build.py OUT).

  OUT/obsidian/Crate/            theme.css (fonts inlined) + manifest.json, the
                                 folder a vault's .obsidian/themes/ takes

Standard library only.
"""
import base64
import json
import os
import re
import shutil
import sys

APPS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(APPS)

# the woff2 files the themes embed or ship, by the name the sources use
FONTS = {
    "roboto-latin": os.path.join(ROOT, "plugin/crate-mark/content/fonts/roboto-latin.woff2"),
    "bricolage-grotesque-latin": os.path.join(ROOT, "theme/fonts/bricolage-grotesque-latin-opsz-normal.woff2"),
    "jetbrains-mono-latin": os.path.join(APPS, "fonts/jetbrains-mono-latin-400-normal.woff2"),
}
FONT_URL = re.compile(r'url\("crate-font:([a-z0-9-]+)"\)')

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


def build_obsidian(out):
    dest = os.path.join(out, "obsidian", "Crate")
    write(os.path.join(dest, "theme.css"), inline_fonts(read(os.path.join(APPS, "obsidian/theme.css"))))
    shutil.copyfile(os.path.join(APPS, "obsidian/manifest.json"), os.path.join(dest, "manifest.json"))
    return dest


def main(argv):
    if len(argv) != 2 or argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if len(argv) == 2 else 2
    out = os.path.abspath(argv[1])
    print("obsidian", build_obsidian(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
