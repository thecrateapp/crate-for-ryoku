#!/usr/bin/env bash
# The Crate lock skins, per user: install copies them next to qylock's themes and remembers the skin
# that was active; uninstall puts that skin back (only when a Crate skin is the active one).
#   lock-skins.sh install | uninstall
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/crate-for-ryoku
THEMES=$DATA/qylock/themes/crate
ACTIVE=$CFG/qylock/theme

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
active_skin() { tr -d '[:space:]' < "$ACTIVE" 2>/dev/null || true; }

case ${1:-} in
  install)
    [ -d "$HERE/lockscreen/crate" ] || { warn "no lock skins in this package"; exit 0; }
    mkdir -p "$STATE"
    # Written once, and never a Crate skin, so a second run cannot record Crate as "previous".
    cur=$(active_skin)
    if [ ! -f "$STATE/previous-lock" ] && [ -n "$cur" ] && [ "${cur#crate/}" = "$cur" ]; then
      printf '%s\n' "$cur" > "$STATE/previous-lock"
      say "recorded your lock skin ($cur) in $STATE/previous-lock"
    fi
    say "lock skins -> $THEMES"
    mkdir -p "$THEMES"
    for skin in hero orbit; do
      rm -rf -- "${THEMES:?}/$skin"
      cp -a "$HERE/lockscreen/crate/$skin" "$THEMES/$skin"
    done
    ;;
  uninstall)
    cur=$(active_skin)
    if [ "${cur#crate/}" != "$cur" ]; then
      prev=$(cat "$STATE/previous-lock" 2>/dev/null || true)
      prev=${prev:-clockwork/orbital}
      say "lock skin -> $prev (ryoku-hub lock set)"
      ryoku-hub lock set "$prev" || warn "could not set $prev; pick a lock skin in Ryoku Settings > Lockscreen"
    fi
    for skin in hero orbit; do
      if [ -d "$THEMES/$skin" ]; then say "removing $THEMES/$skin"; rm -r -- "${THEMES:?}/$skin"; fi
    done
    rmdir "$THEMES" 2>/dev/null || true
    rm -f -- "$STATE/previous-lock"
    ;;
  *) echo "usage: lock-skins.sh install|uninstall" >&2; exit 2 ;;
esac
