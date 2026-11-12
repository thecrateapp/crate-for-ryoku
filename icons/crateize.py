#!/usr/bin/env python3
"""crateize: draw every installed app icon in Crate's icon language.

crate-icons draws the generic system apps by hand. Everything else (Firefox,
Steam, Slack, an app installed tomorrow) gets here and is written to a separate
theme, crate-icons-auto, which crate-icons inherits from:

  crate-icons (hand-drawn)  ->  crate-icons-auto (drawn here)  ->  Papirus-Dark ...

A brand app gets its brand mark (Tabler or Simple Icons, in Crate's colours:
build_icons.brand_svg); a brand with no free mark (app_glyphs.RECOLOR) keeps
its own icon, recoloured. Every other app gets a Solar line-duotone glyph, drawn
exactly like the hand-drawn set (build_icons.py: white ink, one cyan layer): the
glyph app_glyphs.py names for it, or the one for its first freedesktop
category. Only an app none of these names keeps its own icon, recoloured
(--style graded recolours every app instead).

The grade keeps each icon's drawing and gives it Crate's colours:
  - lightness maps onto Crate's ink ramp, lifted off the floor so dark parts
    still read on the dock's dark plate;
  - the icon's dominant hue (its brand colour) becomes Crate cyan, every other
    hue goes neutral: one accent per icon, as in Crate's UI;
  - when that accent covers most of the icon (a one-colour logo disc), it sits
    at the deep end of the Crate logo gradient (#0e7490) so the white mark pops.

The result is baked into plain colours: Quickshell draws icons with Qt's SVG
renderer, which has no filters. SVG sources stay vector (every colour literal
is rewritten); raster sources, and SVGs that embed bitmaps, are graded per pixel.

usage:
  crateize.py [--out DIR] [--keep NAME ...] [--style solar|graded] [--dry-run] [--force]
    --out      theme folder (default $XDG_DATA_HOME/icons/crate-icons-auto)
    --keep     icon names to leave untouched (also read from
               $XDG_CONFIG_HOME/crate-for-ryoku/crateize-keep, one per line)
    --dry-run  list what would be graded, write nothing
    --force    regrade everything, ignoring the manifest
    --style    solar (default): brand marks and Solar glyphs where app_glyphs.py
               has one; graded: recolour every app's own icon

needs python-numpy, python-pillow and rsvg-convert (librsvg).
"""
import configparser
import glob
import hashlib
import io
import json
import math
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import app_glyphs  # noqa: E402  (beside this file)

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
THEME = "crate-icons-auto"
HAND = "crate-icons"
GRADE_VERSION = 3  # bump to regrade everything after changing the grade or the glyphs

# ------------------------------------------------------------------ colour

def _srgb2lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _lin2srgb(c):
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(np.clip(c, 0, None), 1 / 2.4) - 0.055)


def rgb2oklab(rgb):
    r, g, b = (_srgb2lin(rgb[..., i]) for i in range(3))
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], -1)


def oklab2rgb(lab):
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    rgb = np.stack([4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s], -1)
    return np.clip(_lin2srgb(rgb), 0, 1)


_CYAN = rgb2oklab(np.array([0x06, 0xB6, 0xD4]) / 255.0)
CYAN_HUE = math.atan2(_CYAN[2], _CYAN[1])
L_MIN, L_MAX = 0.30, 0.965  # ink ramp: a raised grey up to Crate ink #f1f5f9
ACCENT_C = 0.135            # chroma of the cyan accent
HUE_WIDTH = 0.6             # radians around the dominant hue that count as "the accent"


def dominant_hue(rgba):
    """OKLab hue of the most colourful opaque area, or None for a neutral icon."""
    opaque = rgba[..., 3] > 0.5
    lab = rgb2oklab(rgba[..., :3])
    C = np.hypot(lab[..., 1], lab[..., 2])
    m = opaque & (C > 0.06)
    if m.sum() < 0.04 * max(opaque.sum(), 1):
        return None
    h = np.arctan2(lab[..., 2], lab[..., 1])[m]
    bins = np.histogram(h, bins=24, range=(-math.pi, math.pi), weights=C[m])[0]
    k = int(np.argmax(np.convolve(np.r_[bins[-1], bins, bins[0]], [1, 1, 1], "valid")))
    return -math.pi + (k + 0.5) * (2 * math.pi / 24)


def accent_cover(rgba, hue):
    """Share of the opaque area the accent hue takes."""
    if hue is None:
        return 0.0
    opaque = rgba[..., 3] > 0.5
    lab = rgb2oklab(rgba[..., :3])
    C = np.hypot(lab[..., 1], lab[..., 2])
    dh = np.abs(np.angle(np.exp(1j * (np.arctan2(lab[..., 2], lab[..., 1]) - hue))))
    return float((opaque & (C > 0.06) & (dh < HUE_WIDTH)).sum() / max(opaque.sum(), 1))


def grade(rgb, hue, cover):
    lab = rgb2oklab(rgb)
    L = lab[..., 0]
    C = np.hypot(lab[..., 1], lab[..., 2])
    L2 = L_MIN + (L_MAX - L_MIN) * np.clip(L, 0, 1)
    if hue is None:
        t = np.zeros_like(L)
    else:
        dh = np.abs(np.angle(np.exp(1j * (np.arctan2(lab[..., 2], lab[..., 1]) - hue))))
        half = HUE_WIDTH / 2
        t = np.clip((C - 0.03) / 0.10, 0, 1) * np.clip(1 - (dh - half) / half, 0, 1)
    base = 0.62 - 0.12 * np.clip((cover - 0.35) / 0.3, 0, 1)
    L3 = L2 * (1 - t) + (base + (L2 - 0.62) * 0.45) * t
    C3 = ACCENT_C * t
    return oklab2rgb(np.stack([L3, C3 * math.cos(CYAN_HUE), C3 * math.sin(CYAN_HUE)], -1))

# ------------------------------------------------------------------ files

NAMED = {"white": "#ffffff", "black": "#000000", "red": "#ff0000", "blue": "#0000ff",
         "green": "#008000", "yellow": "#ffff00", "gray": "#808080", "grey": "#808080",
         "orange": "#ffa500", "purple": "#800080"}
_HEX = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")
_RGBF = re.compile(r"rgb(a?)\(\s*([\d.]+%?)\s*,\s*([\d.]+%?)\s*,\s*([\d.]+%?)")
_NAMEDRE = re.compile(r'((?:fill|stroke|stop-color|flood-color|color)\s*[:=]\s*"?)(%s)\b' % "|".join(NAMED))


def rsvg(svg_bytes, px):
    out = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px)], input=svg_bytes,
                         capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(out)).convert("RGBA")


def grade_svg(text, hue, cover):
    def hx(h):
        h = h.lstrip("#")
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        v = grade(np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0, hue, cover)
        return "#%02x%02x%02x" % tuple(int(round(x * 255)) for x in v)

    def rgbf(m):
        vals = [float(x[:-1]) * 2.55 if x.endswith("%") else float(x) for x in m.groups()[1:]]
        v = grade(np.array(vals) / 255.0, hue, cover)
        return "rgb%s(%s" % (m.group(1), ",".join(str(int(round(c * 255))) for c in v))

    text = _HEX.sub(lambda m: hx(m.group(0)), text)
    text = _RGBF.sub(rgbf, text)
    text = _NAMEDRE.sub(lambda m: m.group(1) + hx(NAMED[m.group(2)]), text)
    if not re.search(r"<svg\b[^>]*\sfill=", text):  # implicit black fill
        text = re.sub(r"<svg\b", '<svg fill="%s"' % hx("#000000"), text, count=1)
    return text


def grade_image(im):
    a = np.asarray(im.convert("RGBA")).astype(float) / 255
    hue = dominant_hue(a)
    rgb = grade(a[..., :3], hue, accent_cover(a, hue))
    return Image.fromarray((np.concatenate([rgb, a[..., 3:]], -1) * 255).round().astype("uint8"), "RGBA")


def crateize(src):
    """('svg', bytes) for a vector source, ('png', Image) for a raster one."""
    if src.endswith(".svg"):
        raw = open(src, "rb").read()
        text = raw.decode("utf-8", errors="replace")
        if "<image" not in text:  # bitmaps inside an SVG cannot be recoloured as text
            a = np.asarray(rsvg(raw, 128)).astype(float) / 255
            hue = dominant_hue(a)
            return "svg", grade_svg(text, hue, accent_cover(a, hue)).encode()
        return "png", grade_image(rsvg(raw, 256))
    im = Image.open(src).convert("RGBA")
    if im.size[0] < 256:
        im = im.resize((256, 256), Image.LANCZOS)
    return "png", grade_image(im)

def drawn_svg(kind, ref):
    """A brand mark or Solar glyph as crate-icons draws its own apps (one scalable SVG)."""
    import build_icons  # beside this file; imported here so --style graded needs no glyph data
    if kind == "brand":
        return build_icons.brand_svg(ref, "scalable")
    return build_icons.app_svg(ref, "scalable")


def pick(name, entry, cats, src, style="solar"):
    """What to draw for one app: ("brand", key), ("solar", glyph), ("graded", src) or None.

    A brand without a free mark (RECOLOR) grades its own icon, or gets its
    Solar glyph when there is no icon to grade."""
    if style == "solar":
        choice = app_glyphs.icon_for(name, entry, cats)
        if choice and choice != app_glyphs.RECOLOR:
            return choice
        if choice == app_glyphs.RECOLOR and not src:
            glyph = app_glyphs.glyph_for(name, entry, cats)
            if glyph:
                return ("solar", glyph)
    return ("graded", src) if src else None

# ------------------------------------------------------------------ lookup

def _data_dirs():
    return [DATA] + (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")


def theme_dirs():
    roots = [os.path.join(d, "icons") for d in _data_dirs()] + [os.path.join(HOME, ".icons")]
    roots += ["/var/lib/flatpak/exports/share/icons", os.path.join(DATA, "flatpak/exports/share/icons")]
    return [r for r in roots if os.path.isdir(r)]


def find_theme(name):
    return [os.path.join(r, name) for r in theme_dirs() if os.path.isfile(os.path.join(r, name, "index.theme"))]


def theme_chain():
    """crate-icons, then the themes it inherits from (skipping crate-icons-auto), then hicolor."""
    chain, seen = [], set()

    def walk(name):
        if name in seen:
            return
        seen.add(name)
        paths = find_theme(name)
        if not paths:
            return
        chain.append((name, paths))
        c = configparser.RawConfigParser(strict=False, interpolation=None)
        c.read(os.path.join(paths[0], "index.theme"), encoding="utf-8")
        for parent in c.get("Icon Theme", "Inherits", fallback="").split(","):
            parent = parent.strip()
            if parent and parent != THEME:
                walk(parent)

    walk(HAND)
    walk("hicolor")
    return chain


def index_theme(name, paths):
    """icon name -> (score, path) over the theme's dirs; a higher score is a better source."""
    c = configparser.RawConfigParser(strict=False, interpolation=None)
    c.read(os.path.join(paths[0], "index.theme"), encoding="utf-8")
    dirs = [d.strip() for d in (c.get("Icon Theme", "Directories", fallback="") + "," +
                                c.get("Icon Theme", "ScaledDirectories", fallback="")).split(",") if d.strip()]
    best = {}
    for d in dirs:
        if not c.has_section(d):
            continue
        # apps first; an Icon= that names a device or status icon still resolves
        is_app = c.get(d, "Context", fallback="Applications") in ("Applications", "Apps")
        typ = c.get(d, "Type", fallback="Threshold")
        size = c.getint(d, "Size", fallback=0) * c.getint(d, "Scale", fallback=1)
        for root in paths:
            for f in glob.glob(os.path.join(root, d, "*")):
                base, ext = os.path.splitext(os.path.basename(f))
                if ext not in (".svg", ".png"):
                    continue
                # the biggest drawing wins: small sizes are simplified redraws
                score = (is_app, 10000 if typ == "Scalable" else size, 1 if ext == ".svg" else 0)
                if base not in best or score > best[base][0]:
                    best[base] = (score, os.path.realpath(f))
    return best


def desktop_icons():
    dirs = [os.path.join(d, "applications") for d in _data_dirs()]
    dirs += ["/var/lib/flatpak/exports/share/applications", os.path.join(DATA, "flatpak/exports/share/applications")]
    names = {}
    for d in dirs:
        for f in glob.glob(os.path.join(d, "**/*.desktop"), recursive=True):
            c = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                c.read(f, encoding="utf-8")
                icon = c.get("Desktop Entry", "Icon", fallback="").strip()
                cats = c.get("Desktop Entry", "Categories", fallback="")
            except (configparser.Error, UnicodeDecodeError):
                continue
            if icon:
                names.setdefault(icon, (os.path.basename(f), [x for x in cats.split(";") if x]))
    return names

# ------------------------------------------------------------------ main

INDEX = """[Icon Theme]
Name=Crate (installed apps)
Comment=Generated on this machine by crateize.py: brand marks (Tabler Icons, MIT; Simple Icons, CC0; brand names and logos are trademarks of their respective owners) and Solar glyphs (480 Design, CC BY 4.0) for the installed apps, and the apps' own icons recoloured into Crate's palette where neither fits. Recoloured drawings belong to their apps; this folder is not for redistribution.
Hidden=true
Inherits=Papirus-Dark,breeze-dark,hicolor
Directories=scalable/apps,256x256/apps

[scalable/apps]
Context=Applications
Size=64
MinSize=16
MaxSize=512
Type=Scalable

[256x256/apps]
Context=Applications
Size=256
MinSize=16
MaxSize=512
Type=Scalable
"""


def parse(argv):
    opts = {"out": os.path.join(DATA, "icons", THEME), "keep": set(), "dry": False, "force": False, "style": "solar"}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--out":
            opts["out"] = argv[i + 1]; i += 1
        elif a == "--keep":
            while i + 1 < len(argv) and not argv[i + 1].startswith("--"):
                opts["keep"].add(argv[i + 1]); i += 1
        elif a == "--dry-run":
            opts["dry"] = True
        elif a == "--force":
            opts["force"] = True
        elif a == "--style":
            opts["style"] = argv[i + 1]; i += 1
            if opts["style"] not in ("solar", "graded"):
                sys.exit(f"--style takes solar or graded, not {opts['style']}")
        elif a in ("-h", "--help"):
            print(__doc__); sys.exit(0)
        else:
            sys.exit(f"unknown argument: {a}\n{__doc__}")
        i += 1
    kf = os.path.join(CONFIG, "crate-for-ryoku", "crateize-keep")
    if not os.path.isfile(kf):  # the name before 0.5
        kf = os.path.join(CONFIG, "crate-rice", "crateize-keep")
    if os.path.isfile(kf):
        opts["keep"] |= {l.strip() for l in open(kf) if l.strip() and not l.startswith("#")}
    return opts


def plan(keep, style="solar"):
    chain = theme_chain()
    if not chain or chain[0][0] != HAND:
        sys.exit(f"{HAND} is not installed; install Crate for Ryoku first")
    hand = index_theme(*chain[0])
    sources = [index_theme(n, p) for n, p in chain[1:]]
    pix = "/usr/share/pixmaps"
    pixmaps = {os.path.splitext(f)[0]: os.path.join(pix, f)
               for f in (os.listdir(pix) if os.path.isdir(pix) else []) if f.endswith((".svg", ".png"))}
    todo, skipped = [], {"hand": 0, "kept": 0, "path": 0, "missing": []}
    for name, (entry, cats) in sorted(desktop_icons().items()):
        if os.path.isabs(name):
            skipped["path"] += 1  # an absolute Icon= path bypasses icon themes
        elif name in hand:
            skipped["hand"] += 1
        elif name in keep:
            skipped["kept"] += 1
        else:
            src = next((s[name][1] for s in sources if name in s), None) or pixmaps.get(name)
            choice = pick(name, entry, cats, src, style)
            if choice:
                todo.append((name, choice))
            else:
                skipped["missing"].append(name)
    return todo, skipped


def main(argv):
    opts = parse(argv)
    out = opts["out"]
    todo, skipped = plan(opts["keep"], opts["style"])
    summary = (f"{skipped['hand']} hand-drawn in crate-icons, {skipped['kept']} kept, "
               f"{skipped['path']} absolute Icon= paths, {len(skipped['missing'])} not found")
    if opts["dry"]:
        for name, (kind, ref) in todo:
            print(f"{name:44} {ref if kind == 'graded' else kind + ':' + ref}")
        print(f"{len(todo)} to draw; {summary}")
        return 0

    for d in ("scalable/apps", "256x256/apps"):
        os.makedirs(os.path.join(out, d), exist_ok=True)
    with open(os.path.join(out, "index.theme"), "w") as f:
        f.write(INDEX)
    manifest_path = os.path.join(out, "manifest.json")
    try:
        old = {} if opts["force"] else json.load(open(manifest_path))
    except (OSError, ValueError):
        old = {}
    if old.get("_grade") != GRADE_VERSION:
        old = {k: v for k, v in old.items() if k != "_grade" and isinstance(v, dict)}
        for v in old.values():
            v["key"] = None  # keep the file list for cleanup, force a regrade

    new, done, reused = {"_grade": GRADE_VERSION}, 0, 0
    drawn = {"brand": 0, "solar": 0}
    for name, (kind, ref) in todo:
        if kind == "graded":
            src = ref
            st = os.stat(src)
            key = hashlib.sha1(f"{src}:{st.st_size}:{int(st.st_mtime)}".encode()).hexdigest()
        else:
            key = f"{kind}:{ref}"
        prev = old.get(name)
        if prev and prev.get("key") == key and os.path.exists(os.path.join(out, prev["file"])):
            new[name] = prev; reused += 1
            continue
        if kind != "graded":
            rel = f"scalable/apps/{name}.svg"
            with open(os.path.join(out, rel), "w") as f:
                f.write(drawn_svg(kind, ref))
            new[name] = {"key": key, "file": rel, kind: ref}
            done += 1; drawn[kind] += 1
            continue
        try:
            kind, data = crateize(src)
        except Exception as e:  # one broken icon must not stop the rest
            print(f"!! {name}: {e}", file=sys.stderr)
            continue
        rel = f"scalable/apps/{name}.svg" if kind == "svg" else f"256x256/apps/{name}.png"
        if kind == "svg":
            with open(os.path.join(out, rel), "wb") as f:
                f.write(data)
        else:
            data.save(os.path.join(out, rel))
        new[name] = {"key": key, "file": rel, "src": src}
        done += 1

    # remove only files this tool wrote before and no longer wants
    wanted = {v["file"] for k, v in new.items() if k != "_grade"}
    for k, v in old.items():
        if k != "_grade" and isinstance(v, dict) and v.get("file") not in wanted:
            p = os.path.join(out, v["file"])
            if os.path.isfile(p):
                os.remove(p)
    with open(manifest_path, "w") as f:
        json.dump(new, f, indent=1, sort_keys=True)

    graded = done - drawn["brand"] - drawn["solar"]
    print(f"crate-icons-auto: {drawn['brand']} brand marks, {drawn['solar']} Solar glyphs, {graded} graded, "
          f"{reused} unchanged; {summary}")
    if skipped["missing"]:
        print("  not found: " + ", ".join(skipped["missing"][:12]) + (" ..." if len(skipped["missing"]) > 12 else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
