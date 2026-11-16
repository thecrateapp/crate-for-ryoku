#!/usr/bin/env bash
# Build the lock-screen assets that are not committed:
#   common/fonts/        Bricolage Grotesque and JetBrains Mono as TTF (QML FontLoader reads TTF), with their OFL texts
#   common/backgrounds/  groove.webp and sheen.webp at 3840x2400 (lossless)
# Needs python-cairo, numpy and Pillow for the wallpapers. The font conversion needs fontTools
# and brotli; when system python lacks either, it runs through `uvx`.
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
COMMON=$HERE/crate/common
FONTS=$COMMON/fonts
BACKS=$COMMON/backgrounds
mkdir -p "$FONTS" "$BACKS"

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
  python3 -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2], "WEBP", lossless=True, quality=100, method=6)' "$png" "$dst"
  rm -f -- "$png"
  echo "built $dst"
done
