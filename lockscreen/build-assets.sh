#!/usr/bin/env bash
# Build the lock-screen assets that are not committed:
#   common/fonts/        Bricolage Grotesque and JetBrains Mono as TTF (QML FontLoader reads TTF), with their OFL texts
#   common/backgrounds/  groove.webp and sheen.webp at 3840x2400 (lossless)
# Needs python-cairo, numpy and Pillow for the wallpapers. The font conversion needs fontTools
# and brotli; when system python lacks either, it runs through `uvx`.
# Files that already exist are kept; --force rebuilds everything (the package build does, so a stale
# render is never shipped).
set -euo pipefail
FORCE=0
case "${1:-}" in
  --force) FORCE=1 ;;
  "") ;;
  *) echo "usage: build-assets.sh [--force]" >&2; exit 2 ;;
esac
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
COMMON=$HERE/crate/common
FONTS=$COMMON/fonts
BACKS=$COMMON/backgrounds
mkdir -p "$FONTS" "$BACKS"
if [ "$FORCE" = 1 ]; then rm -f -- "$FONTS"/*.ttf "$FONTS/OFL.txt" "$BACKS"/*.webp; fi

woff2_to_ttf='
import sys
from fontTools.ttLib import TTFont
f = TTFont(sys.argv[1])
f.flavor = None
f.save(sys.argv[2])
'
if python3 -c 'import fontTools, brotli' 2>/dev/null; then
  py=(python3)
else
  py=(uvx --with fonttools --with brotli python)
fi
convert_font() {
  [ -s "$2" ] && return 0
  "${py[@]}" -c "$woff2_to_ttf" "$1" "$2"
  echo "built $2"
}
convert_font "$REPO/theme/fonts/bricolage-grotesque-latin-opsz-normal.woff2" "$FONTS/BricolageGrotesque.ttf"
convert_font "$REPO/tools/cut/public/fonts/jetbrains-mono-latin-400-normal.woff2" "$FONTS/JetBrainsMono-Regular.ttf"
{
  cat "$REPO/theme/fonts/OFL.txt"
  printf '\n\n----\n\n'
  cat "$REPO/tools/cut/public/fonts/OFL-jetbrains-mono.txt"
} > "$FONTS/OFL.txt"

for name in groove sheen; do
  dst=$BACKS/$name.webp
  [ -s "$dst" ] && continue
  png=$(mktemp --suffix=.png)
  python3 "$REPO/wallpaper/$name.py" 3840 2400 "$png"
  # Lock-screen copies only: the desktop wallpapers stay as generated. A gamma lift (blacks stay 0)
  # brings the dark art to a visible wallpaper level; dither hides banding in the lifted gradients.
  python3 - "$png" "$dst" <<'PY'
import sys
import numpy as np
from PIL import Image
GAMMA = 0.68
img = np.asarray(Image.open(sys.argv[1]).convert("RGB"), dtype=np.float32) / 255.0
out = np.power(img, GAMMA) * 255.0
out += np.random.default_rng(7).uniform(-0.5, 0.5, out.shape).astype(np.float32)
Image.fromarray(np.clip(np.rint(out), 0, 255).astype(np.uint8)).save(sys.argv[2], "WEBP", lossless=True, quality=100, method=6)
PY
  rm -f -- "$png"
  echo "built $dst"
done
