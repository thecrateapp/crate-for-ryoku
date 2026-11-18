#!/usr/bin/env bash
# Render the Crate boot themes into OUT/boot (run: package/build-boot.sh OUT):
#   plymouth/crate  the splash: script, mark.png from brand/crate-logo.svg, beam and prompt PNGs
#   grub/crate      the menu: theme.txt, background, fonts, selection mark
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

G=$out/boot/grub/crate
mkdir -p "$G"
cp "$repo/boot/grub/crate/theme.txt" "$G/"
font=$repo/apps/fonts/jetbrains-mono-latin-400-normal.woff2
for size in 16 24; do
  # -n sets the family only; grub-mkfont adds "Regular <size>" itself
  grub-mkfont -s "$size" -n "JetBrains Mono" -o "$G/jetbrains-mono-$size.pf2" "$font"
done
# the Groove wallpaper (render.sh writes it into build/); a canvas when it is not built
wall=${CRATE_BOOT_WALLPAPER:-$repo/build/wallpapers/crate-groove-3840x2160.webp}
python3 - "$G" "$wall" <<'PY'
import os, sys
from PIL import Image
d, wall = sys.argv[1], sys.argv[2]
if os.path.isfile(wall):
    Image.open(wall).convert("RGB").resize((1920, 1080), Image.LANCZOS).save(f"{d}/background.png", optimize=True)
else:
    print(f"build-boot: {wall} not built; a plain canvas background", file=sys.stderr)
    Image.new("RGB", (1920, 1080), (10, 10, 15)).save(f"{d}/background.png")
clear = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
for part in ("n", "ne", "e", "se", "s", "sw", "nw", "c"):
    clear.save(f"{d}/select_{part}.png")
Image.new("RGBA", (2, 1), (6, 182, 212, 255)).save(f"{d}/select_w.png")   # the cyan mark
PY
echo "boot: grub theme in $G"
