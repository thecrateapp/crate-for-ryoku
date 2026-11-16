#!/usr/bin/env bash
# The Crate lock skins, per user: install copies them next to qylock's themes and remembers the skin
# that was active; restore puts that skin back (only when a Crate skin is the active one); uninstall
# restores, then removes the skins.
#   lock-skins.sh install | restore | uninstall
# The session skin is written here, the way Ryoku's own rice apply does it (an atomic write of
# ~/.config/qylock/theme). `ryoku-hub lock set` is never called: it also re-skins the SDDM greeter
# through pkexec, and putting the look back must not raise a privilege prompt. The greeter keeps
# whatever skin it has until the user picks another in Ryoku Settings > Lockscreen.
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
# an installed skin by a slug that cannot escape the themes folder
skin_exists() {
  case $1 in ''|/*|*..*) return 1 ;; esac
  [ -f "$DATA/qylock/themes/$1/Main.qml" ]
}
set_active() {
  mkdir -p "$(dirname "$ACTIVE")"
  local tmp
  tmp=$(mktemp "$ACTIVE.XXXXXX")
  printf '%s\n' "$1" > "$tmp"
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$ACTIVE"
}
# A Crate skin is active: put back the recorded one, else clockwork/orbital, else no choice at all
# (qylock's lock.sh falls back to its own orbital).
restore_skin() {
  local cur prev skin
  cur=$(active_skin)
  [ "${cur#crate/}" != "$cur" ] || return 0
  prev=$(tr -d '[:space:]' < "$STATE/previous-lock" 2>/dev/null || true)
  for skin in "$prev" clockwork/orbital; do
    if skin_exists "$skin"; then
      say "lock skin -> $skin"
      set_active "$skin"
      return 0
    fi
  done
  say "lock skin -> qylock's default (${prev:-no previous skin} is not installed)"
  rm -f -- "$ACTIVE"
}

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
  restore)
    restore_skin
    ;;
  uninstall)
    restore_skin
    for skin in hero orbit; do
      if [ -d "$THEMES/$skin" ]; then say "removing $THEMES/$skin"; rm -r -- "${THEMES:?}/$skin"; fi
    done
    rmdir "$THEMES" 2>/dev/null || true
    rm -f -- "$STATE/previous-lock"
    ;;
  *) echo "usage: lock-skins.sh install|restore|uninstall" >&2; exit 2 ;;
esac
