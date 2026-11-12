#!/usr/bin/env python3
"""Build the crate-icons freedesktop icon theme.

A small overlay theme in Crate v3's visual language: raised dark surfaces,
hairline edges, white ink and one localized cyan element per icon. It draws
folders, places, the generic system apps and the brand apps app_glyphs.py
names (Firefox, Slack, Steam: their marks in Crate's colours). Everything it
does not draw (mimetypes, symbolic icons) is inherited from crate-icons-auto,
then Papirus-Dark, which ships with Ryoku.

The glyphs are Crate's own icon set: Solar (480 Design, CC BY 4.0), the family
@crate/ui wraps through @solar-icons/react. solar-line-duotone.json vendors the
line-duotone weight, rendered by solar_export.mjs; it has the geometry of the
outline weight Crate's UI uses, as strokes, so each output size can get its own
line weight. The duotone split picks the accent: the lighter of the two layers
is drawn in cyan, the rest in white ink.

Brand marks come from brand-icons.json (brand_export.mjs): Tabler Icons line
brands (MIT), drawn with Solar's stroke weight, and Simple Icons silhouettes
(CC0), filled in ink at the same optical size. Each gets one cyan element where
the mark has a natural one (Chrome's centre, Steam's piston).

Tiles and folders sit on a 64-unit grid; Solar glyphs and brand marks on their
24-unit grid.

Tokens (app/web/src/styles/tokens.css, app/shared/ui/tokens/themes.css):
  bg #0a0a0f  panel #0d0e14  raised #15161d  fg #f1f5f9  muted #999ca0
  faint #4a4c52  cyan #06b6d4  cyan-hi #67e8f9

usage: build_icons.py OUT_DIR LOGO_SVG [--apps glyph|tile]
  --apps glyph  (default) app icons are the bare glyph, which sits on the dock's
                own plate; tile puts each glyph on a raised Crate tile.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FG = "#f1f5f9"
MUTED = "#999ca0"
CYAN = "#06b6d4"
CYAN_HI = "#67e8f9"

# device-pixel stroke per output size; "scalable" is tuned at 64 px and scales.
SIZES = {16: 1.15, 22: 1.35, 24: 1.45, 32: 1.6, "scalable": 2.4}
NOMINAL = {16: 16, 22: 22, 24: 24, 32: 32, "scalable": 64}
# Solar is drawn at 1.5 on its 24 grid; keep the per-size stroke near that so
# its tight details (calculator signs, list bullets) never clog at 16 px.
SOLAR_STROKE = (1.35, 2.1)

# Solar icon -> the duotone layer drawn in cyan (the lighter one, measured by
# rendering each layer alone). "secondary" = the layer Solar fades to 50%.
ACCENT = {
    "programming": "primary", "folder-with-files": "secondary", "pulse": "primary",
    "settings": "primary", "pen-new-square": "primary", "calculator-minimalistic": "secondary",
    "calendar": "secondary", "clock-circle": "primary", "cloud-sun-2": "secondary",
    "gallery": "secondary", "vinyl-record": "primary", "video-library": "secondary",
    "document-text": "primary", "archive": "primary", "camera-square": "primary",
    "camera": "primary", "ssd-round": "secondary", "pie-chart-2": "primary",
    "volume-loud": "secondary", "box": "secondary", "clipboard-list": "primary",
    "question-circle": "primary", "text-square": "primary", "trash-bin-trash": "secondary",
}

# app icon names, by the Solar glyph they get (generic system apps only)
APPS = {
    "programming": ["kitty", "Alacritty", "org.gnome.Console", "org.gnome.Terminal", "utilities-terminal",
                    "terminator", "terminal", "org.kde.konsole"],
    "folder-with-files": ["org.kde.dolphin", "org.gnome.Nautilus", "system-file-manager", "yazi", "nautilus",
                          "file-manager", "thunar", "org.xfce.thunar"],
    "pulse": ["btop", "org.gnome.SystemMonitor", "utilities-system-monitor", "gnome-system-monitor",
              "htop", "org.kde.plasma-systemmonitor"],
    "settings": ["org.gnome.Settings", "preferences-system", "preferences-desktop", "gnome-control-center",
                 "systemsettings"],
    "pen-new-square": ["org.gnome.TextEditor", "org.gnome.gedit", "accessories-text-editor", "micro",
                       "text-editor", "gedit", "org.kde.kate", "kate"],
    "calculator-minimalistic": ["org.gnome.Calculator", "accessories-calculator", "gnome-calculator",
                                "org.kde.kcalc"],
    "calendar": ["org.gnome.Calendar", "x-office-calendar", "office-calendar"],
    "clock-circle": ["org.gnome.clocks", "preferences-system-time", "gnome-clocks"],
    "cloud-sun-2": ["org.gnome.Weather", "weather", "gnome-weather"],
    "gallery": ["org.gnome.Loupe", "org.gnome.eog", "image-viewer", "eog", "org.kde.gwenview"],
    "vinyl-record": ["org.gnome.Music", "org.gnome.Decibels", "multimedia-audio-player", "audio-player",
                     "gnome-music"],
    "video-library": ["org.gnome.Showtime", "org.gnome.Totem", "multimedia-video-player",
                                    "video-player", "totem"],
    "document-text": ["org.gnome.Papers", "org.gnome.Evince", "evince", "org.kde.okular", "okular"],
    "archive": ["org.gnome.FileRoller", "file-roller", "utilities-file-archiver", "org.kde.ark", "ark"],
    "camera-square": ["org.gnome.Screenshot", "applets-screenshooter", "gnome-screenshot",
                          "org.kde.spectacle"],
    "camera": ["org.gnome.Snapshot", "camera-app", "org.gnome.Cheese", "cheese"],
    "ssd-round": ["org.gnome.DiskUtility", "gnome-disks", "drive-harddisk-system"],
    "pie-chart-2": ["org.gnome.baobab", "baobab", "org.gnome.Usage", "filelight", "org.kde.filelight"],
    "volume-loud": ["org.pulseaudio.pavucontrol", "pavucontrol", "multimedia-volume-control"],
    "box": ["org.gnome.Software", "octopi", "system-software-install", "gnome-software", "org.kde.discover"],
    "clipboard-list": ["org.gnome.Logs", "gnome-logs", "utilities-log-viewer"],
    "question-circle": ["org.gnome.Yelp", "help-browser", "yelp", "help-contents"],
    "text-square": ["org.gnome.font-viewer", "org.gnome.Characters", "preferences-desktop-font",
                    "gnome-font-viewer", "accessories-character-map"],
}

# place folders, by the Solar emblem on their front (None = plain folder)
PLACES = {
    None: ["folder", "inode-directory", "folder-open", "folder_open", "folder-cyan", "default-folder"],
    "home": ["user-home", "folder-home", "folder_home", "go-home"],
    "monitor": ["user-desktop", "folder-desktop", "desktop"],
    "document-text": ["folder-documents", "folder-document", "folder-text"],
    "download-minimalistic": ["folder-download", "folder-downloads"],
    "music-note-2": ["folder-music", "folder-sound"],
    "gallery": ["folder-pictures", "folder-picture", "folder-images", "folder-image", "folder-photos"],
    "video-library": ["folder-videos", "folder-video", "folder-movies"],
    "widget": ["folder-templates", "folder-template"],
    "share": ["folder-publicshare", "folder-public"],
    "global": ["folder-remote", "folder-network", "network-workgroup"],
    "code": ["folder-code", "folder-development", "folder-projects", "folder-script"],
    "star": ["folder-favorites", "user-bookmarks", "folder-bookmark", "folder-bookmarks"],
    "branching-paths-up": ["folder-git", "folder-github", "folder-gitlab"],
}

# ---------------------------------------------------------------- Solar

SOLAR = json.load(open(os.path.join(HERE, "solar-line-duotone.json")))
# the glyphs crateize.py draws for installed apps (app_glyphs.py), vendored from
# @solar-icons/react-perf by solar_export_perf.mjs; solar_accents.py measured
# which of each one's layers is the lighter, the one drawn in cyan
_EXTRA = os.path.join(HERE, "solar-line-duotone-extra.json")
if os.path.isfile(_EXTRA):
    _extra = json.load(open(_EXTRA))
    for _name, _markup in _extra["icons"].items():
        SOLAR["icons"].setdefault(_name, _markup)
        ACCENT.setdefault(_name, _extra.get("accents", {}).get(_name))

_EL = re.compile(r"<(path|circle|rect|ellipse|line|polyline|polygon)\b([^>]*?)/?>(?:</\1>)?")


def solar_layers(name):
    """The icon's elements as (is_secondary, tag, attrs) with Solar's styling stripped."""
    out = []
    for tag, attrs in _EL.findall(SOLAR["icons"][name]):
        secondary = "solar-secondary" in attrs
        attrs = re.sub(r'\s*style="[^"]*"', "", attrs)
        out.append((secondary, tag, attrs))
    return out


def solar_glyph(name, sw, accent=None, mono=None, dim_accent=False):
    """Solar icon `name` as an SVG group on its 24 grid.

    mono: draw every layer in this colour (folder emblems). Otherwise the layer
    named in ACCENT is cyan (or muted ink when dim_accent) and the rest is ink."""
    sw = max(SOLAR_STROKE[0], min(SOLAR_STROKE[1], sw))
    accent = accent or ACCENT.get(name)
    parts = []
    for secondary, tag, attrs in solar_layers(name):
        layer = "secondary" if secondary else "primary"
        if mono:
            color, op = mono, 1.0
        elif layer == accent:
            color, op = (MUTED, 0.75) if dim_accent else (CYAN_HI, 1.0)
        else:
            color, op = FG, 0.94
        attrs = attrs.replace('stroke="currentColor"', f'stroke="{color}" stroke-opacity="{op}"')
        attrs = attrs.replace('fill="currentColor"', f'fill="{color}" fill-opacity="{op}"')
        parts.append(f"<{tag}{attrs}/>")
    return (f'<g fill="none" stroke-width="{sw:.3f}" stroke-linecap="round" stroke-linejoin="round">'
            + "".join(parts) + "</g>")


# ---------------------------------------------------------------- brands

sys.path.insert(0, HERE)
import app_glyphs  # noqa: E402  (beside this file)

# icon name -> (source, mark) for the brand apps this theme draws itself
BRAND_NAMES = {n: b for n, b in app_glyphs.BRANDS.items() if b != app_glyphs.RECOLOR}

_BRANDS_JSON = os.path.join(HERE, "brand-icons.json")
BRANDS = json.load(open(_BRANDS_JSON)) if os.path.isfile(_BRANDS_JSON) else {"sources": {}, "icons": {}}

# optical size: the mark's 24 grid is scaled by this about its centre so it
# reads as large as a Solar glyph. Tabler draws inside 3..21 where Solar uses
# 2..22; Simple Icons fill the whole 24 square, and a filled shape looks bigger
# than a line of the same extent.
LINE_FIT = 1.1
FILL_FIT = 0.78
BRAND_FIT = {
    # dense squares and discs read heavier than line art of the same extent
    "simple-icons/jetbrains": 0.7, "simple-icons/phpstorm": 0.7, "simple-icons/webstorm": 0.7,
    "simple-icons/qemu": 0.72, "simple-icons/thunderbird": 0.72, "simple-icons/postman": 0.72,
    "simple-icons/mpv": 0.74, "simple-icons/onlyoffice": 0.76,
    # open or narrow marks need more extent to carry the same weight
    "simple-icons/claude": 0.8, "simple-icons/cachyos": 0.8, "simple-icons/nvidia": 0.8,
    "simple-icons/vim": 0.8, "simple-icons/obsidian": 0.82, "simple-icons/electron": 0.86,
    "simple-icons/wine": 0.86,
}

# the mark's one cyan element, as Crate's own glyphs have: Tabler element
# indices, or Simple Icons subpath indices (split_subpaths) painted over the
# silhouette in cyan, so a cut-out subpath becomes a cyan inlay. Absent: all ink.
BRAND_ACCENT = {
    "tabler/brand-chrome": (1,), "tabler/brand-firefox": (1,), "tabler/brand-mongodb": (0,),
    "tabler/brand-slack": (0,), "tabler/brand-steam": (1,),
    "simple-icons/cachyos": (1, 2, 3), "simple-icons/cmake": (3,), "simple-icons/electron": (5,),
    "simple-icons/jetbrains": (1,), "simple-icons/localsend": (1, 2, 3, 4, 5, 6, 7, 8),
    "simple-icons/mpv": (4,), "simple-icons/nvidia": (0,), "simple-icons/obsidian": (2,),
    "simple-icons/onlyoffice": (0,), "simple-icons/phpstorm": (0,), "simple-icons/postman": tuple(range(1, 11)),
    "simple-icons/qemu": (2,), "simple-icons/thunderbird": (1,), "simple-icons/vim": (1, 2, 4),
    "simple-icons/webstorm": (3,), "simple-icons/wine": (1,),
}


_TOK = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
_ARGS = {"m": 2, "l": 2, "h": 1, "v": 1, "c": 6, "s": 4, "q": 4, "t": 2, "a": 7, "z": 0}


def split_subpaths(d):
    """A path's subpaths as stand-alone path data, each starting with an absolute M.

    Minified paths start a subpath with a relative m and pack arc flags
    ("a1 1 0 011 1"), so this tracks the current point through every command."""
    toks = _TOK.findall(d)[::-1]  # a stack: packed flags push their remainder back
    subs, cur = [], []
    x = y = sx = sy = 0.0
    cmd = None
    while toks:
        if toks[-1].isalpha():
            cmd = toks.pop()
            if cmd in "Zz":
                cur.append(cmd)
                x, y = sx, sy
            continue
        args = []
        for k in range(_ARGS[cmd.lower()]):
            t = toks.pop()
            if cmd in "Aa" and k in (3, 4) and len(t) > 1:  # a flag is one digit
                toks.append(t[1:])
                t = t[0]
            args.append(t)
        v = [float(a) for a in args]
        rel = cmd.islower()
        if cmd in "Mm":
            x, y = (x + v[0], y + v[1]) if rel else (v[0], v[1])
            if cur:
                subs.append("".join(cur))
            cur, sx, sy = [f"M{x:g} {y:g}"], x, y
            cmd = "l" if rel else "L"  # further pairs after a moveto are line-tos
            continue
        cur.append(cmd + " ".join(args))
        if cmd in "Hh":
            x = x + v[0] if rel else v[0]
        elif cmd in "Vv":
            y = y + v[0] if rel else v[0]
        else:
            x, y = (x + v[-2], y + v[-1]) if rel else (v[-2], v[-1])
    if cur:
        subs.append("".join(cur))
    return subs


def brand_kind(key):
    return "line" if key.startswith("tabler/") else "fill"


def brand_fit(key):
    return BRAND_FIT.get(key, LINE_FIT if brand_kind(key) == "line" else FILL_FIT)


def brand_glyph(key, sw):
    """Brand mark `key` (source/name) as an SVG group on the 24 grid, in Crate colours.

    sw is the stroke a Solar glyph would get here; a line mark gets the same
    weight on screen, a silhouette is filled and has no stroke."""
    fit = brand_fit(key)
    accent = BRAND_ACCENT.get(key, ())
    ink, cyan = (FG, 0.94), (CYAN_HI, 1.0)
    place = f'transform="translate(12 12) scale({fit}) translate(-12 -12)"'
    elements = _EL.findall(BRANDS["icons"][key])
    if brand_kind(key) == "fill":
        d = re.search(r'\sd="([^"]*)"', elements[0][1]).group(1)
        parts = [f'<path d="{d}" fill="{ink[0]}" fill-opacity="{ink[1]}"/>']
        subs = split_subpaths(d)
        parts += [f'<path d="{subs[i]}" fill="{cyan[0]}"/>' for i in accent]
        return f"<g {place}>" + "".join(parts) + "</g>"
    parts = []
    # the accent goes last, so the ink crossing it never cuts it
    for i, (tag, attrs) in sorted(enumerate(elements), key=lambda e: e[0] in accent):
        color, op = cyan if i in accent else ink
        attrs = attrs.replace('fill="currentColor"', f'fill="{color}" fill-opacity="{op}"')
        parts.append(f'<{tag}{attrs} stroke="{color}" stroke-opacity="{op}"/>')
    sw = max(SOLAR_STROKE[0], min(SOLAR_STROKE[1], sw)) / fit
    return (f'<g {place}><g fill="none" stroke-width="{sw:.3f}" stroke-linecap="round" '
            'stroke-linejoin="round">' + "".join(parts) + "</g></g>")


# ---------------------------------------------------------------- drawing


def stroke_units(size, grid_scale):
    """Stroke width in glyph units for one output size (grid_scale: glyph unit -> 64-grid units)."""
    return SIZES[size] * 64.0 / NOMINAL[size] / grid_scale


def svg(body, defs=""):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
            f"<defs>{defs}</defs>{body}</svg>\n")


def hair(size):
    """One device pixel in 64-grid units (a touch heavier on the scalable art)."""
    return 64.0 / NOMINAL[size] * (1.0 if size != "scalable" else 1.4)


def tile(size, uid):
    h = hair(size)
    defs = (f'<linearGradient id="t{uid}" x1="0" y1="5" x2="0" y2="59" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#1a1b23"/><stop offset="1" stop-color="#0c0d12"/></linearGradient>')
    i = h / 2
    body = (f'<rect x="{5 + i:.3f}" y="{5 + i:.3f}" width="{54 - h:.3f}" height="{54 - h:.3f}" rx="13.5" '
            f'fill="url(#t{uid})" stroke="{FG}" stroke-opacity="0.16" stroke-width="{h:.3f}"/>'
            # a faint top sheen: the hairline highlight Crate puts on raised panels
            f'<path d="M18 {5 + h * 1.5:.3f}h28" stroke="{FG}" stroke-opacity="0.08" '
            f'stroke-width="{h:.3f}" stroke-linecap="round"/>')
    return defs, body


APP_STYLE = "glyph"
GLYPH_SCALE = 2.2  # bare glyph: Solar's 24 grid onto 52.8 units, its ~20-unit art spans ~44


def _app(name, size, glyph):
    """A 24-grid glyph (glyph(sw) -> SVG group) as an app icon: bare, or on the tile."""
    if APP_STYLE == "glyph":
        s = GLYPH_SCALE
        o = 32 - 12 * s
        return svg(f'<g transform="translate({o:.3f} {o:.3f}) scale({s})">{glyph(stroke_units(size, s))}</g>')
    defs, body = tile(size, re.sub(r"[^a-z0-9]", "", name))
    scale = 1.5  # the 24 grid into a 36-unit box centred in the tile
    body += f'<g transform="translate(14 14) scale({scale})">{glyph(stroke_units(size, scale))}</g>'
    return svg(body, defs)


def app_svg(name, size, **kw):
    return _app(name, size, lambda sw: solar_glyph(name, sw, **kw))


def brand_svg(key, size):
    """Brand mark `key` (source/name, from app_glyphs.BRANDS) as an app icon, like app_svg."""
    return _app(key, size, lambda sw: brand_glyph(key, sw))


def folder_svg(emblem, size):
    h = hair(size)
    small = NOMINAL[size] <= 24
    edge = 0.3 if small else 0.2  # small folders need a firmer edge to read on a dark view
    defs = ('<linearGradient id="fb" x1="0" y1="13" x2="0" y2="54" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#1c1d25"/><stop offset="1" stop-color="#121319"/></linearGradient>'
            '<linearGradient id="ff" x1="0" y1="23" x2="0" y2="55" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#23252e"/><stop offset="1" stop-color="#14151b"/></linearGradient>')
    back = ("M9 12.5h13.2a3 3 0 0 1 2.3 1.1l2.6 3.2a3 3 0 0 0 2.3 1.1H55a3 3 0 0 1 3 3V51"
            "a3 3 0 0 1-3 3H9a3 3 0 0 1-3-3V15.5a3 3 0 0 1 3-3z")
    body = (f'<path d="{back}" fill="url(#fb)" stroke="{FG}" stroke-opacity="0.16" stroke-width="{h:.3f}"/>'
            # sheets inside the folder: the records in the crate
            f'<path d="M12 21.5h40 M14 18.8h22" stroke="{FG}" stroke-opacity="0.13" stroke-width="{h:.3f}" '
            'stroke-linecap="round"/>'
            f'<rect x="6" y="24" width="52" height="30" rx="3.2" fill="url(#ff)" stroke="{FG}" '
            f'stroke-opacity="{edge}" stroke-width="{h:.3f}"/>'
            f'<path d="M9 {24 + h:.3f}h46" stroke="{FG}" stroke-opacity="0.09" stroke-width="{h:.3f}"/>')
    if emblem is None:
        # the plain folder's one accent: the tab edge
        tab_sw = SIZES[size] * 64.0 / NOMINAL[size]
        body += (f'<path d="M10 12.5h11.5" stroke="{CYAN}" stroke-width="{tab_sw:.3f}" '
                 'stroke-linecap="round"/>')
    else:
        es = 0.9 if small else 0.78  # Solar's 24 grid onto the folder front
        g = solar_glyph(emblem, stroke_units(size, es), mono=CYAN_HI)
        ox, oy = 32 - 12 * es, 39.5 - 12 * es
        body += f'<g transform="translate({ox:.3f} {oy:.3f}) scale({es})">{g}</g>'
    return svg(body, defs)


def crate_svg(size, logo_svg):
    """The Crate app icon: the real Crate logo, bare or on the tile."""
    defs, body = tile(size, "crate") if APP_STYLE == "tile" else ("", "")
    inner = logo_svg.split(">", 1)[1].rsplit("</svg>", 1)[0]
    inner = re.sub(r'id="g(\d)"', r'id="cl\1"', inner)
    inner = re.sub(r'url\(#g(\d)\)', r'url(#cl\1)', inner)
    h = 34.0 if APP_STYLE == "tile" else 48.0
    s = h / 1120.0
    w = 1052 * s
    body += f'<g transform="translate({32 - w / 2:.3f} {32 - h / 2:.3f}) scale({s:.5f})">{inner}</g>'
    return svg(body, defs)


INDEX = """[Icon Theme]
Name=Crate
Comment=Crate v3 icons for Crate for Ryoku on Ryoku. Glyphs: Solar Icons Set by 480 Design (CC BY 4.0); brand marks: Tabler Icons (MIT) and Simple Icons (CC0), trademarks of their owners. Everything else comes from Papirus-Dark.
Inherits=crate-icons-auto,Papirus-Dark,breeze-dark,hicolor
Example=folder
DesktopDefault=48
DesktopSizes=16,22,24,32,48,64
ToolbarDefault=22
ToolbarSizes=16,22,24,32
MainToolbarDefault=22
MainToolbarSizes=16,22,24,32
PanelDefault=48
PanelSizes=16,22,24,32,48,64

Directories={dirs}

"""

CREDITS = """crate-icons: Crate for Ryoku icon theme for Ryoku.

Glyphs: Solar Icons Set by 480 Design
  https://www.figma.com/community/file/1166831539721848736
  licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)
  taken from @solar-icons/react {version} (line-duotone weight), recoloured and
  placed on Crate folders (and tiles, in the tile build).
Brand marks: Tabler Icons by Pawel Kuna, MIT License (https://tabler.io/icons),
  @tabler/icons {tabler} (outline brands), and Simple Icons, CC0 1.0
  (https://simpleicons.org), simple-icons {simple}; recoloured and drawn with
  Crate's line weight. Brand names and logos are trademarks of their respective
  owners; their use here identifies the apps and implies no endorsement.
Crate logo: Crate (cratemusic.app).
Tiles, folders and the build script: part of Crate for Ryoku.
"""


def main(out, logo_path):
    logo = open(logo_path).read()
    dirs, sections = [], []
    for size in SIZES:
        name = "scalable" if size == "scalable" else f"{size}x{size}"
        for ctx, context in (("apps", "Applications"), ("places", "Places")):
            d = f"{name}/{ctx}"
            dirs.append(d)
            os.makedirs(os.path.join(out, d), exist_ok=True)
            if size == "scalable":
                sections.append(f"[{d}]\nContext={context}\nSize=64\nMinSize=25\nMaxSize=512\nType=Scalable\n")
            else:
                sections.append(f"[{d}]\nContext={context}\nSize={size}\nType=Fixed\n")

    count = 0

    def put(path, data):
        nonlocal count
        with open(path, "w") as f:
            f.write(data)
        count += 1

    for size in SIZES:
        name = "scalable" if size == "scalable" else f"{size}x{size}"
        apps = os.path.join(out, name, "apps")
        places = os.path.join(out, name, "places")
        for glyph, names in APPS.items():
            data = app_svg(glyph, size)
            for n in names:
                put(os.path.join(apps, n + ".svg"), data)
        # brand apps by exact name; crateize.py catches prefixed names (JetBrains)
        for n, (src, mark) in sorted(BRAND_NAMES.items()):
            put(os.path.join(apps, n + ".svg"), brand_svg(f"{src}/{mark}", size))
        data = crate_svg(size, logo)
        for n in ("app.cratemusic.crate.desktop", "app.cratemusic.crate", "crate", "crate-desktop"):
            put(os.path.join(apps, n + ".svg"), data)
        for emblem, names in PLACES.items():
            data = folder_svg(emblem, size)
            for n in names:
                put(os.path.join(places, n + ".svg"), data)
        # trash: the bin's slats are the accent once it holds something
        for full, names in ((False, ["user-trash", "trash-empty"]), (True, ["user-trash-full", "trash-full"])):
            data = app_svg("trash-bin-trash", size, dim_accent=not full)
            for n in names:
                put(os.path.join(places, n + ".svg"), data)

    with open(os.path.join(out, "index.theme"), "w") as f:
        f.write(INDEX.format(dirs=",".join(dirs)))
        f.write("\n".join(sections))
    with open(os.path.join(out, "CREDITS"), "w") as f:
        f.write(CREDITS.format(version=SOLAR.get("version", ""),
                               tabler=BRANDS["sources"].get("tabler", {}).get("version", ""),
                               simple=BRANDS["sources"].get("simple-icons", {}).get("version", "")))
    print(f"wrote {count} icons into {out}")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--apps" in args:
        i = args.index("--apps")
        APP_STYLE = args[i + 1]
        del args[i:i + 2]
    if APP_STYLE not in ("glyph", "tile") or len(args) != 2:
        sys.exit(__doc__)
    main(args[0], args[1])
