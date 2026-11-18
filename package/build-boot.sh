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
