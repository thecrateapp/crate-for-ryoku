#!/usr/bin/env bash
# Undo install.sh: put back the look you had before Crate, then remove the
# pieces this package installed. Your wallpapers folder is left alone unless
# you pass --purge.
set -euo pipefail

CFG=${XDG_CONFIG_HOME:-$HOME/.config}
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/crate-for-ryoku
PICS=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
WALLDIR=$PICS/Wallpapers

KEEP=0 PURGE=0
for a in "$@"; do
  case $a in
    --keep-files) KEEP=1 ;;
    --purge) PURGE=1 ;;
    -h|--help)
      cat <<EOF
usage: uninstall.sh [--keep-files] [--purge]
  --keep-files  only revert the look; leave the theme, icons, rice and plugin installed
  --purge       also delete the crate-*.webp wallpapers from $WALLDIR
EOF
      exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }

PREV_ICON_THEME="" PREV_RICE=""
# shellcheck disable=SC1091
[ -f "$STATE/previous.env" ] && . "$STATE/previous.env"

active=$(cat "$CFG/ryoku/rices/.active" 2>/dev/null || true)
if [ "$active" = crate ]; then
  say "restoring the look from before Crate (ryoku-hub rice restore previous)"
  ryoku-hub rice restore previous || warn "rice restore failed; pick another rice in Ryoku Settings > Appearance > Rices"
else
  say "Crate is not the active rice (${active:-none}); leaving the look as it is"
fi

target=${PREV_ICON_THEME:-Papirus-Dark}
[ "$target" = crate-icons ] && target=Papirus-Dark
say "icon theme -> $target"
ryoku-hub desktop icon-theme set "$target" || warn "could not set $target; choose one in Ryoku Settings > App icon theme"

if [ "$KEEP" = 0 ]; then
  if ryoku plugin list 2>/dev/null | grep -q 'crate-mark'; then
    say "removing the crate-mark plugin"
    ryoku plugin remove crate-mark || warn "could not remove crate-mark"
  fi
  if [ -f "$CFG/systemd/user/crate-icons-auto.path" ]; then
    say "removing the crate-icons-auto watcher"
    ryoku-host svc --user disable --now crate-icons-auto.path >/dev/null 2>&1 || true
    rm -f -- "$CFG/systemd/user/crate-icons-auto.path" "$CFG/systemd/user/crate-icons-auto.service"
    command -v systemctl >/dev/null && systemctl --user daemon-reload 2>/dev/null || true
  fi
  rm -f -- "$STATE/crate-present"
  rm -f -- "$CFG/fish/conf.d/crate-prompt.fish" "$HOME/.local/bin/crate-for-ryoku-installed" "$STATE/version"
  if head -1 "$CFG/eza/theme.yml" 2>/dev/null | grep -q -E '^# crate-(rice|for-ryoku): eza'; then rm -f -- "$CFG/eza/theme.yml"; fi
  # drop only the rice's "cr" launcher entry
  if [ -f "$CFG/ryoku/launcher-scripts.json" ]; then
    python3 - "$CFG/ryoku/launcher-scripts.json" <<'PY' || true
import json, sys
path = sys.argv[1]
try:
    scripts = json.load(open(path))
except (OSError, ValueError):
    sys.exit(0)
if isinstance(scripts, list):
    kept = [s for s in scripts if not (isinstance(s, dict) and s.get("keyword") == "cr" and "--launcher" in (s.get("exec") or []))]
    json.dump(kept, open(path, "w"), indent=2)
PY
  fi
  for d in "$DATA/icons/crate-icons" "$DATA/icons/crate-icons-auto" "$DATA/crate-for-ryoku" "$DATA/fonts/crate-for-ryoku" \
           "$DATA/crate-rice" "$DATA/fonts/crate-rice"; do  # and the names before 0.5
    if [ -d "$d" ]; then say "removing $d"; rm -r -- "$d"; fi
  done
  # the scheme and the rice go only once Crate is no longer the active look
  if [ "$(cat "$CFG/ryoku/rices/.active" 2>/dev/null || true)" != crate ]; then
    for d in "$DATA/ryoku/themes/crate" "$CFG/ryoku/rices/crate"; do
      if [ -d "$d" ]; then say "removing $d"; rm -r -- "$d"; fi
    done
  else
    warn "Crate is still the active rice; keeping its scheme and rice folder"
  fi
fi

if [ "$PURGE" = 1 ]; then
  for n in groove sheen horizon handoff macro; do
    f=$WALLDIR/crate-$n.webp
    if [ -f "$f" ]; then rm -- "$f"; fi
  done
  say "removed the crate-*.webp wallpapers"
fi

ryoku-shell reload >/dev/null || true
if [ "$KEEP" = 0 ] && [ -f "$STATE/previous.env" ]; then mv "$STATE/previous.env" "$STATE/previous.env.done"; fi
say "done"
