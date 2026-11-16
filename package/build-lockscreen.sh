#!/usr/bin/env bash
# Build the Crate lock skins into DEST (lockscreen/ inside the dist): crate/hero and crate/orbit, each
# self-contained (the shared module vendored as common/, fonts and backgrounds freshly built, a
# preview.gif for Ryoku's Settings > Lockscreen gallery). No test harness and no preview tool ships.
#   build-lockscreen.sh DEST
set -euo pipefail
SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LOCK=$SRC/lockscreen
DEST=${1:?usage: build-lockscreen.sh DEST}
command -v qs >/dev/null || { echo "build-lockscreen.sh: quickshell (qs) is needed to render the previews" >&2; exit 1; }

# never ship whatever the git-ignored asset folders happen to hold
bash "$LOCK/build-assets.sh" --force

rm -rf -- "$DEST"
for skin in hero orbit; do
  out=$DEST/crate/$skin
  mkdir -p "$out"
  cp -a "$LOCK/crate/$skin/." "$out/"
  cp -a "$LOCK/crate/common" "$out/common"
  # the skin and the shared module live in one folder now
  find "$out" -type f -name '*.qml' -exec sed -i 's#\.\./common#common#g' {} +
done

# preview.gif: idle, typing, checking, error at 16:9, looping
frames=$(mktemp -d)
trap 'rm -rf -- "$frames"' EXIT
for skin in hero orbit; do
  i=0
  for state in idle typing checking error; do
    bash "$LOCK/preview.sh" "crate/$skin" "$state" --shot "$frames/$skin-$i.png" --size 800x450 >/dev/null
    i=$((i + 1))
  done
  python3 - "$frames" "$skin" "$DEST/crate/$skin/preview.gif" <<'PY'
import sys
from PIL import Image
frames_dir, skin, out = sys.argv[1:4]
frames = [Image.open(f"{frames_dir}/{skin}-{i}.png").convert("RGB").resize((400, 225), Image.LANCZOS) for i in range(4)]
pal = [f.quantize(colors=128, dither=Image.Dither.FLOYDSTEINBERG) for f in frames]
pal[0].save(out, save_all=True, append_images=pal[1:], duration=[1800, 1300, 900, 1800], loop=0, optimize=True)
PY
done
echo "built $DEST"
