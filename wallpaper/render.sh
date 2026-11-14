#!/usr/bin/env bash
# Render the Crate wallpaper, Groove, as lossless WebP into OUT_DIR (default
# build/wallpapers), at 3840x2160 and 3840x2400. A render already there is kept, so a
# rebuild only pays for what changed. Needs python-cairo, numpy and Pillow.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT=${1:-$HERE/../build/wallpapers}
mkdir -p "$OUT"
webp() { python3 -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2], "WEBP", lossless=True, quality=100, method=6)' "$1" "$2"; }
for size in 3840x2160 3840x2400; do
  w=${size%x*} h=${size#*x}
  dst=$OUT/crate-groove-$size.webp
  [ -s "$dst" ] && continue
  png=$(mktemp --suffix=.png)
  python3 "$HERE/groove.py" "$w" "$h" "$png"
  webp "$png" "$dst" && rm -f -- "$png"
  echo "rendered $dst"
done
