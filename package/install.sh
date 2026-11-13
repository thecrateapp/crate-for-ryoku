#!/usr/bin/env bash
# Install Crate for Ryoku (Ryoku 1.0.7+): colour scheme, icon theme, bar
# plugin, terminal styling, wallpapers and the rice itself, all through
# Ryoku's own commands.
# Everything lands in your home; nothing needs root. uninstall.sh undoes it.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VERSION=$(cat "$HERE/VERSION")
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/crate-for-ryoku
PICS=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
WALLDIR=$PICS/Wallpapers

APPLY=1 ICONS=1 AUTO=1 PLUGIN=1 WALLS=1 REAPPLY=0

usage() {
  cat <<EOF
Crate for Ryoku $VERSION

usage: install.sh [options]
  --no-apply       install the pieces but do not switch to the rice
  --no-icons       skip the crate-icons icon theme (and the graded app icons)
  --no-auto-icons  do not grade the other apps' icons into the Crate palette
  --no-plugin      skip the crate-mark bar plugin
  --no-wallpapers  do not copy the wallpaper set into $WALLDIR
  --reapply        apply the rice again even if Crate is already active
                   (Ryoku's .previous snapshot then holds the current Crate state)
  -h, --help       this help
EOF
}

for a in "$@"; do
  case $a in
    --no-apply) APPLY=0 ;;
    --no-icons) ICONS=0 AUTO=0 ;;
    --no-auto-icons) AUTO=0 ;;
    --no-plugin) PLUGIN=0 ;;
    --no-wallpapers) WALLS=0 ;;
    --reapply) REAPPLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $a" >&2; usage >&2; exit 2 ;;
  esac
done

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mxx\033[0m %s\n' "$*" >&2; exit 1; }

for c in ryoku ryoku-hub ryoku-shell; do
  command -v "$c" >/dev/null || die "$c not found: this package needs a Ryoku desktop"
done
[ -d /usr/share/icons/Papirus-Dark ] || warn "Papirus-Dark is not installed; crate-icons falls back to breeze-dark/hicolor for the icons it does not draw"
# grep reads all of fc-list (no -q): an early exit would SIGPIPE fc-list and trip pipefail
fc-list : family 2>/dev/null | grep -F "JetBrainsMono Nerd Font" >/dev/null || warn "JetBrainsMono Nerd Font is missing (pacman -S ttf-jetbrains-mono-nerd)"

# copy_into SRC DEST: copy a folder's contents over DEST (created if needed).
copy_into() { mkdir -p "$2"; cp -a "$1/." "$2/"; }

active_rice() { cat "$CFG/ryoku/rices/.active" 2>/dev/null || true; }
current_icons() { ryoku-hub desktop icon-theme 2>/dev/null | sed -n 's/.*"theme":"\([^"]*\)".*/\1/p'; }

# Crate for Ryoku was "the Crate rice" (crate-rice) up to 0.4: carry its
# folders over so its record of what to go back to survives the rename.
for old_new in "$DATA/crate-rice:$DATA/crate-for-ryoku" "$CFG/crate-rice:$CFG/crate-for-ryoku" \
               "${XDG_STATE_HOME:-$HOME/.local/state}/crate-rice:$STATE" \
               "$DATA/fonts/crate-rice:$DATA/fonts/crate-for-ryoku"; do
  old=${old_new%%:*} new=${old_new#*:}
  [ -d "$old" ] || continue
  if [ -e "$new" ]; then rm -r -- "$old"; else mkdir -p "$(dirname "$new")" && mv "$old" "$new"; fi
  say "moved $old -> $new"
done

mkdir -p "$STATE"
# What uninstall.sh goes back to. Written once, on the first install, so a
# second run never records Crate as "previous".
if [ ! -f "$STATE/previous.env" ]; then
  {
    printf 'PREV_ICON_THEME=%q\n' "$(current_icons)"
    printf 'PREV_RICE=%q\n' "$(active_rice)"
    printf 'INSTALLED_AT=%q\n' "$(date -Iseconds)"
  } > "$STATE/previous.env"
  say "recorded your current icon theme and rice in $STATE/previous.env"
fi

say "colour scheme -> $DATA/ryoku/themes/crate"
copy_into "$HERE/theme/crate" "$DATA/ryoku/themes/crate"
# Crate's display face (Bricolage Grotesque, OFL), named by the scheme's style
# block; Ryoku builds that read it (themeStyle) use it for Ryoku.Ui titles
copy_into "$HERE/theme/fonts" "$DATA/fonts/crate-for-ryoku"
fc-cache -f "$DATA/fonts/crate-for-ryoku" >/dev/null 2>&1 || true

if [ "$ICONS" = 1 ]; then
  say "icon theme -> $DATA/icons/crate-icons"
  copy_into "$HERE/icons/crate-icons" "$DATA/icons/crate-icons"
fi

if [ "$AUTO" = 1 ]; then
  # every other app keeps its own icon, recoloured into the Crate palette, in a
  # theme generated on this machine (crate-icons inherits from it)
  if python3 -c 'import numpy, PIL' 2>/dev/null && command -v rsvg-convert >/dev/null; then
    mkdir -p "$DATA/crate-for-ryoku" "$CFG/systemd/user"
    cp "$HERE"/icons/{crateize.py,build_icons.py,app_glyphs.py,solar-line-duotone.json,solar-line-duotone-extra.json,brand-icons.json} "$DATA/crate-for-ryoku/"
    say "drawing the other apps' icons (Solar glyphs) -> $DATA/icons/crate-icons-auto"
    python3 "$DATA/crate-for-ryoku/crateize.py" || warn "crateize failed; apps keep their Papirus icons"
    cp "$HERE"/systemd/crate-icons-auto.{path,service} "$CFG/systemd/user/"
    # services go through Ryoku's host seam; only the unit-file reload is systemd's own
    command -v systemctl >/dev/null && systemctl --user daemon-reload 2>/dev/null || true
    if ryoku-host svc --user enable --now crate-icons-auto.path >/dev/null 2>&1; then
      say "apps installed later get their icons too (crate-icons-auto.path)"
    else
      warn "could not enable crate-icons-auto.path; re-run $DATA/crate-for-ryoku/crateize.py after installing apps"
    fi
  else
    warn "graded app icons need python-numpy, python-pillow and librsvg; skipping (apps keep their Papirus icons)"
  fi
fi

if [ "$WALLS" = 1 ]; then
  # one resolution per frame, matched to the focused monitor's aspect
  res=3840x2160
  if command -v hyprctl >/dev/null && hyprctl monitors -j >/dev/null 2>&1; then
    if hyprctl monitors -j | python3 -c 'import json,sys
m=[x for x in json.load(sys.stdin) if x.get("focused")] or [None]
m=m[0]
sys.exit(0 if m and abs(m["width"]/m["height"]-1.6)<0.02 else 1)' 2>/dev/null; then
      res=3840x2400
    fi
  fi
  mkdir -p "$WALLDIR"
  for f in "$HERE"/wallpapers/crate-*-"$res".webp; do
    name=$(basename "$f" "-$res.webp")
    dest=$WALLDIR/$name.webp
    if [ -f "$dest" ] && cmp -s "$f" "$dest"; then continue; fi
    cp "$f" "$dest"
  done
  say "wallpapers ($res, lossless WebP) -> $WALLDIR/crate-*.webp"
fi

say "rice -> $CFG/ryoku/rices/crate"
copy_into "$HERE/rice/crate" "$CFG/ryoku/rices/crate"

if [ "$PLUGIN" = 1 ]; then
  want=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$HERE/plugin/crate-mark/manifest.json" | head -1)
  have=$(ryoku plugin list 2>/dev/null | awk '$1=="crate-mark"{print $2}')
  if [ -z "$have" ]; then
    say "bar plugin crate-mark $want"
    ryoku plugin add "$HERE/plugin/crate-mark" --bar --yes
  elif [ "$have" != "$want" ]; then
    # ryoku plugin has no upgrade verb: remove, add, and place it again below
    say "bar plugin crate-mark $have -> $want"
    ryoku plugin remove crate-mark
    ryoku plugin add "$HERE/plugin/crate-mark" --bar --yes
  else
    say "bar plugin crate-mark $want already installed"
  fi
  # the mark shows only while the Crate app is installed (re-checked by the
  # crate-icons-auto watcher whenever apps change)
  mkdir -p "$DATA/crate-for-ryoku"
  cp "$HERE/crate-presence.sh" "$DATA/crate-for-ryoku/crate-presence.sh"
fi

if [ "$APPLY" = 1 ]; then
  if [ "$(active_rice)" = crate ] && [ "$REAPPLY" = 0 ]; then
    say "Crate is already the active rice: not re-applying, so your .previous snapshot stays as it is"
    if [ "$PLUGIN" = 1 ]; then
      ryoku-shell bar move crate-mark --section left --after launcher >/dev/null || warn "could not place crate-mark after the launcher"
    fi
  else
    # Ryoku overwrites .previous on every apply; keep a copy of the one we replace.
    if [ -d "$CFG/ryoku/rices/.previous" ]; then
      cp -a "$CFG/ryoku/rices/.previous" "$STATE/previous-slot-$(date +%Y%m%d-%H%M%S)"
    fi
    say "applying the rice (ryoku-hub rice apply crate)"
    ryoku-hub rice apply crate
    # apply writes theme.theme but does not resolve the palette; this does.
    ryoku-shell theme crate
  fi
  if [ "$ICONS" = 1 ]; then
    say "icon theme crate-icons (GTK, Qt, KDE and gsettings)"
    ryoku-hub desktop icon-theme set crate-icons
  fi
  # the dock and launcher re-index icons on a shell reload
  ryoku-shell reload >/dev/null || true
fi

# Ryoku's launcher: "cr <query>" searches the Crate library and plays the pick,
# through Crate's own rofi-script mode (crate-desktop --launcher, Crate 3.4+).
# Ryoku has no command for launcher-scripts.json (Script.qml documents it as
# the place to declare scripts), so only the "cr" entry is added or updated.
# Detect support without running it: an older Crate would open its window.
crate_bin=$(command -v crate-desktop 2>/dev/null || true)
if [ -n "$crate_bin" ] && grep -qaF "ROFI_RETV" "$(readlink -f "$crate_bin")"; then
  # the bare name, resolved on PATH at each run: a stored absolute path broke as
  # soon as Crate moved (a manual ~/.local install replaced by the package)
  python3 - "$CFG/ryoku/launcher-scripts.json" crate-desktop <<'PY' && say 'launcher: type "cr <query>" to search and play from Crate'
import json, os, sys
path, exe = sys.argv[1], sys.argv[2]
try:
    scripts = json.load(open(path))
    if not isinstance(scripts, list):
        scripts = []
except (OSError, ValueError):
    scripts = []
entry = {"keyword": "cr", "name": "Crate", "exec": [exe, "--launcher"]}
scripts = [s for s in scripts if not (isinstance(s, dict) and s.get("keyword") == "cr")] + [entry]
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(scripts, f, indent=2)
os.replace(tmp, path)
PY
fi

if [ "$PLUGIN" = 1 ]; then
  # forget the last decision so this install shows or hides the mark afresh
  rm -f -- "$STATE/crate-present"
  bash "$DATA/crate-for-ryoku/crate-presence.sh" || true
  if [ "$(cat "$STATE/crate-present" 2>/dev/null)" = hidden ]; then
    say "the Crate app is not installed: the bar mark stays hidden until it is"
  fi
fi

# the Pure fish prompt in Crate's palette: a conf.d file of global overrides,
# only when Pure is installed (it does nothing otherwise)
if [ -f "$CFG/fish/conf.d/pure.fish" ]; then
  cp "$HERE/shell/crate-prompt.fish" "$CFG/fish/conf.d/crate-prompt.fish"
  say "fish prompt: Pure in Crate colours ($CFG/fish/conf.d/crate-prompt.fish)"
fi

# eza in Crate's palette, monochrome by intensity; never over a theme of yours
EZA_THEME="$CFG/eza/theme.yml"
if [ ! -e "$EZA_THEME" ] || head -1 "$EZA_THEME" | grep -q -E '^# crate-(rice|for-ryoku): eza'; then
  mkdir -p "$CFG/eza" && cp "$HERE/shell/eza-theme.yml" "$EZA_THEME"
  say "eza: Crate theme ($EZA_THEME)"
else
  say "eza: you have your own $EZA_THEME; left as it is"
fi

# what is installed, and a marker command Ryostore's bundle detects this
# per-user setup by (crate-for-ryoku-installed prints the version)
echo "$VERSION" > "$STATE/version"
mkdir -p "$HOME/.local/bin"
printf '#!/bin/sh\n# Crate for Ryoku: installed for this user (crate-for-ryoku status)\ncat "%s/version"\n' "$STATE" > "$HOME/.local/bin/crate-for-ryoku-installed"
chmod +x "$HOME/.local/bin/crate-for-ryoku-installed"

say "done. Undo with: crate-for-ryoku uninstall (or $HERE/uninstall.sh)"
say "GUI: Ryoku Settings > Appearance > Rices (Super+comma) and QS Bar Settings > Community > Crate"
