#!/usr/bin/env bash
# Render the Crate boot themes into OUT/boot (run: package/build-boot.sh OUT):
#   plymouth/crate  the splash: script, mark.png from brand/crate-logo.svg, beam and prompt PNGs
#   refind/crate    the boot menu: theme.conf, banner, logos, selection, font
# Nothing here needs root; package/boot.sh turns the themes on.
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/.." && pwd)
out=${1:?usage: build-boot.sh OUT}

P=$out/boot/plymouth/crate
mkdir -p "$P"
cp "$repo/boot/plymouth/crate/crate.plymouth" "$repo/boot/plymouth/crate/crate.script" "$P/"
rsvg-convert -h 96 "$repo/brand/crate-logo.svg" -o "$P/mark.png"
python3 - "$P" <<'PY'
import sys
from PIL import Image, ImageDraw
d = sys.argv[1]
Image.new("RGBA", (1, 1), (241, 245, 249, 26)).save(f"{d}/beam-track.png")   # hairline
Image.new("RGBA", (1, 2), (6, 182, 212, 255)).save(f"{d}/beam-fill.png")     # cyan fill
b = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
ImageDraw.Draw(b).ellipse((0, 0, 7, 7), fill=(241, 245, 249, 255))
b.save(f"{d}/bullet.png")
e = Image.new("RGBA", (240, 32), (0, 0, 0, 0))
ImageDraw.Draw(e).rounded_rectangle((0, 0, 239, 31), radius=6, outline=(241, 245, 249, 26), width=1)
e.save(f"{d}/entry.png")
PY
echo "boot: plymouth theme in $P"

F=$out/boot/refind/crate
mkdir -p "$F/icons"
cp "$repo/boot/refind/crate/theme.conf" "$F/"
python3 - "$repo" "$F" <<'PY'
# rEFInd in the look of Ryoku's reload cover under Crate (theme/crate/cover-mark.svg,
# a tracked caps line with its kanji gloss, a beam), drawn for a 3840x2400 screen
import json, os, re, subprocess, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
repo, out = sys.argv[1], sys.argv[2]
W, H = 3840, 2400
CANVAS, CYAN, HI, SEC, FAINT, HAIR = (10, 10, 15), (6, 182, 212), (103, 232, 249), (153, 156, 160), (107, 109, 113), (33, 34, 38)
mono = f"{repo}/apps/fonts/jetbrains-mono-latin-400-normal.woff2"
cjk = subprocess.run(["fc-match", "-f", "%{file}", "Noto Sans CJK JP"], capture_output=True, text=True).stdout.strip()

def svg_png(svg, w, h, path):
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", path], input=svg.encode(), check=True)

def width(text, font, track):
    return sum(font.getlength(c) + track for c in text) - track

# ---- banner: canvas, the cover mark with its glow, the label, the beam ----
bg = Image.new("RGBA", (W, H), (*CANVAS, 255))
mh = int(H * 0.11)
tmp = f"{out}/.mark.png"
subprocess.run(["rsvg-convert", "-h", str(mh), "-o", tmp, f"{repo}/theme/crate/cover-mark.svg"], check=True)
mark = Image.open(tmp).convert("RGBA"); os.remove(tmp)
mx, my = W // 2 - mark.width // 2, int(H * 0.2)
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
tint = Image.new("RGBA", mark.size, (*HI, 0)); tint.putalpha(mark.split()[3].point(lambda a: int(a * 0.5)))
glow.paste(tint, (mx, my), tint)
bg = Image.alpha_composite(bg, glow.filter(ImageFilter.GaussianBlur(mh * 0.18)))
bg.alpha_composite(mark, (mx, my))
d = ImageDraw.Draw(bg)
size = int(H * 0.0125)
f = ImageFont.truetype(mono, size)
label, gloss, track = "SELECT A SYSTEM", "起動", int(size * 0.32)
fj = ImageFont.truetype(cjk, size) if cjk and os.path.isfile(cjk) else None
lw = width(label, f, track) + ((size + fj.getlength(gloss)) if fj else 0)
ly = my + mark.height + int(H * 0.028)
x = W // 2 - lw / 2
for ch in label:
    d.text((x, ly), ch, font=f, fill=SEC); x += f.getlength(ch) + track
if fj:
    d.text((x - track + size, ly - size * 0.08), gloss, font=fj, fill=FAINT)
by, bw = ly + int(H * 0.034), int(H * 0.15)
d.line((W // 2 - bw // 2, by, W // 2 + bw // 2, by), fill=HAIR, width=2)
glint = Image.new("RGBA", (bw // 4, 10), (0, 0, 0, 0)); gd = ImageDraw.Draw(glint)
for i in range(glint.width):
    a = int(255 * max(0.0, 1 - abs(i - glint.width / 2) / (glint.width / 2)))
    gd.line((i, 4, i, 5), fill=(*HI, a))
bg.alpha_composite(glint.filter(ImageFilter.GaussianBlur(1.2)), (W // 2 - bw // 2 + bw // 5, by - 4))
bg.convert("RGB").save(f"{out}/banner.png", optimize=True)

# ---- the systems: their own marks in Crate's secondary tone ----
logo = 112
brand = json.load(open(f"{repo}/icons/brand-icons.json"))["icons"]["simple-icons/cachyos"]
svg = brand if isinstance(brand, str) else (brand.get("svg") or brand.get("path"))
if not svg.lstrip().startswith("<svg"):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="{svg}"/></svg>'
svg = re.sub(r'fill="(?!none)[^"]*"', 'fill="#999ca0"', svg)
if 'fill="#999ca0"' not in svg:
    svg = svg.replace("<svg ", '<svg fill="#999ca0" ', 1)
def padded(svg_text, path, box=128, inner=logo):
    svg_png(svg_text, inner, inner, path)
    im = Image.open(path).convert("RGBA"); c = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    c.alpha_composite(im, ((box - inner) // 2, (box - inner) // 2)); c.save(path)
padded(svg, f"{out}/icons/os_cachyos.png")
win = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#999ca0">'
       '<rect x="3" y="3" width="8.5" height="8.5" rx="0.8"/><rect x="12.5" y="3" width="8.5" height="8.5" rx="0.8"/>'
       '<rect x="3" y="12.5" width="8.5" height="8.5" rx="0.8"/><rect x="12.5" y="12.5" width="8.5" height="8.5" rx="0.8"/></svg>')
padded(win, f"{out}/icons/os_win.png", inner=96)

# ---- tools: Solar line duotone glyphs (and every default rEFInd may add) ----
sol = json.load(open(f"{repo}/icons/solar-line-duotone-extra.json"))["icons"]
line = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#999ca0" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">{}</svg>'
tools = {
    "func_shutdown": line.format('<path d="M12 3v8"/><path opacity=".5" d="M7.5 6.2a7.5 7.5 0 1 0 9 0"/>'),
    "func_reset": line.format('<path opacity=".5" d="M20 12a8 8 0 1 1-2.34-5.66"/><path d="M20 4v4h-4"/>'),
    "func_exit": line.format('<path opacity=".5" d="M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4"/><path d="M10 8l-4 4 4 4M6 12h9"/>'),
    "func_firmware": sol["cpu"].replace("currentColor", "#999ca0"),
    "func_about": sol["info-circle"].replace("currentColor", "#999ca0"),
}
for name, s in tools.items():
    svg_png(s, 48, 48, f"{out}/icons/{name}.png")

# ---- selection: raised, 6 px corners, hairline, a cyan pick-edge at the bottom ----
def selection(size, path):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0)); dd = ImageDraw.Draw(im)
    dd.rounded_rectangle((0, 0, size - 1, size - 1), radius=6, fill=(15, 16, 22, 255), outline=(241, 245, 249, 26))
    dd.line((size * 0.3, size - 3, size * 0.7, size - 3), fill=CYAN, width=3)
    im.save(path)
selection(176, f"{out}/selection_big.png")
selection(72, f"{out}/selection_small.png")

# ---- font: rEFInd's 96-cell strip (ASCII 32..127), black glyphs it inverts on a dark
#      banner, caps drawn for lowercase and tracked cells ----
fs = ImageFont.truetype(mono, 36)
cell = int(fs.getlength("M") + 10); fh = 48
strip = Image.new("RGBA", (cell * 96, fh), (0, 0, 0, 0)); sd = ImageDraw.Draw(strip)
for i, code in enumerate(range(32, 128)):
    ch = chr(code).upper() if code < 127 else " "
    sd.text((i * cell + 5, 4), ch, font=fs, fill=(0, 0, 0, 255))
px = strip.load()
for yy in range(fh):
    for xx in range(strip.width):
        r, g, b, a = px[xx, yy]
        if a:
            px[xx, yy] = (0, 0, 0, a)
strip.save(f"{out}/font.png")
PY
echo "boot: refind theme in $F"
