#!/usr/bin/env bash
# Assemble the distributable Crate for Ryoku from this repository:
#   dist/crate-for-ryoku-<version>/        the folder install.sh runs from
#   dist/crate-for-ryoku-<version>.tar.gz  (with SHA256SUMS inside)
# The icon theme is regenerated from build_icons.py and the Crate logo; the
# wallpapers are rendered by wallpaper/render.sh into build/ (kept between
# builds).
set -euo pipefail

SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VER=$(cat "$SRC/package/VERSION")
NAME=crate-for-ryoku-$VER
DIST=$SRC/dist
OUT=$DIST/$NAME
LOGO=$SRC/brand/crate-logo.svg

case $OUT in "$SRC"/dist/crate-for-ryoku-*) ;; *) echo "refusing to build into $OUT" >&2; exit 1 ;; esac
rm -rf -- "$OUT" "$OUT.tar.gz"
mkdir -p "$OUT"/{rice,theme,icons,plugin,wallpapers,systemd}

cp -a "$SRC/rice/crate" "$OUT/rice/crate"
cp -a "$SRC/theme/crate" "$OUT/theme/crate"
cp -a "$SRC/theme/fonts" "$OUT/theme/fonts"
python3 "$SRC/icons/build_icons.py" "$OUT/icons/crate-icons" "$LOGO"
# crateize draws the installed apps with the same brand and Solar code as the hand-drawn set
cp "$SRC"/icons/{crateize.py,build_icons.py,app_glyphs.py,solar-line-duotone.json,solar-line-duotone-extra.json,brand-icons.json} "$OUT/icons/"
cp "$SRC"/package/systemd/crate-icons-auto.{path,service} "$OUT/systemd/"
cp "$SRC/package/crate-presence.sh" "$OUT/crate-presence.sh"
mkdir -p "$OUT/shell" && cp "$SRC/shell/crate-prompt.fish" "$SRC/shell/eza-theme.yml" "$OUT/shell/"
mkdir -p "$OUT/apps/zapfast" && cp "$SRC/apps/zapfast/Crate.json" "$OUT/apps/zapfast/"
# Obsidian, Firefox and Chrome themes (fonts inlined, the add-on zipped); a
# Firefox add-on AMO has signed ships beside them (apps/firefox/signed/)
python3 "$SRC/apps/build.py" "$OUT/apps" >/dev/null
if ls "$SRC"/apps/firefox/signed/*.xpi >/dev/null 2>&1; then
  mkdir -p "$OUT/apps/firefox/signed" && cp "$SRC"/apps/firefox/signed/*.xpi "$OUT/apps/firefox/signed/"
fi
cp -a "$SRC/plugin/crate-mark" "$OUT/plugin/crate-mark"
# the Crate Palette launcher, without its tests and tools
mkdir -p "$OUT/launcher/crate-palette"
(cd "$SRC/launcher/crate-palette" && cp -a --parents $(find . -type f ! -path './tests/*' ! -path './tools/*') "$OUT/launcher/crate-palette/")
bash "$SRC/wallpaper/render.sh" "$SRC/build/wallpapers"
# Groove and Sheen only: an older render of a retired wallpaper in build/ is not shipped
cp "$SRC"/build/wallpapers/crate-{groove,sheen}-*.webp "$OUT/wallpapers/"
# ZapFast's chat wallpaper: Groove quieted behind the conversation
chat_wall=$SRC/build/wallpapers/zapfast-chat.webp
[ -s "$chat_wall" ] || python3 "$SRC/wallpaper/chat.py" "$SRC/build/wallpapers/crate-groove-3840x2400.webp" "$chat_wall"
cp "$chat_wall" "$OUT/apps/zapfast/chat.webp"
cp "$SRC/package/install.sh" "$SRC/package/uninstall.sh" "$SRC/package/apps.sh" "$SRC/package/README.md" "$SRC/package/VERSION" "$OUT/"
cp "$SRC/LICENSE" "$SRC/NOTICE" "$OUT/"
mkdir -p "$OUT/bin" && cp "$SRC/bin/crate-for-ryoku" "$OUT/bin/" && chmod +x "$OUT/bin/crate-for-ryoku"
chmod +x "$OUT/install.sh" "$OUT/uninstall.sh" "$OUT/apps.sh" "$OUT/crate-presence.sh"

if command -v ryoku >/dev/null; then
  ryoku plugin validate "$OUT/plugin/crate-mark"
fi
bash -n "$OUT/install.sh"
bash -n "$OUT/uninstall.sh"
bash -n "$OUT/apps.sh"
bash -n "$OUT/crate-presence.sh"
bash -n "$OUT/bin/crate-for-ryoku"
python3 -m py_compile "$OUT"/icons/{crateize,build_icons,app_glyphs}.py && rm -rf -- "$OUT/icons/__pycache__"

(cd "$OUT" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar -C "$DIST" -czf "$OUT.tar.gz" "$NAME"
echo "built $OUT"
echo "      $OUT.tar.gz ($(du -h "$OUT.tar.gz" | cut -f1))"
