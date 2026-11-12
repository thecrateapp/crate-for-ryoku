#!/usr/bin/env bash
# Show the crate-mark bar plugin only while the Crate desktop app is installed.
#
# A Ryoku bar plugin cannot remove its own slot (the host keeps a few pixels for
# any loaded plugin), so Crate for Ryoku does it from outside, through the
# shell's own command: `ryoku-shell bar show|hide crate-mark`. This runs on
# install and from crate-icons-auto.service whenever the applications folders
# change. It acts only when Crate appears or disappears, so a mark you hid
# yourself in QS Bar Settings stays hidden.
set -u

DATA=${XDG_DATA_HOME:-$HOME/.local/share}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/crate-for-ryoku
IDS="Crate app.cratemusic.crate.desktop crate-desktop"

crate_installed() {
  local dirs dir id
  IFS=: read -r -a dirs <<< "$DATA:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  dirs+=("/var/lib/flatpak/exports/share" "$DATA/flatpak/exports/share")
  for dir in "${dirs[@]}"; do
    for id in $IDS; do
      [ -f "$dir/applications/$id.desktop" ] && return 0
    done
  done
  command -v crate-desktop >/dev/null 2>&1
}

command -v ryoku-shell >/dev/null 2>&1 || exit 0
# nothing to do when the plugin itself is not installed
ryoku plugin list 2>/dev/null | awk '$1=="crate-mark"{found=1} END{exit !found}' || exit 0

want=hidden
crate_installed && want=shown
mkdir -p "$STATE"
last=$(cat "$STATE/crate-present" 2>/dev/null || true)
[ "$want" = "$last" ] && exit 0

verb=hide
[ "$want" = shown ] && verb=show
if ryoku-shell bar "$verb" crate-mark >/dev/null 2>&1; then
  printf '%s\n' "$want" > "$STATE/crate-present"
  echo "crate-mark: $want (Crate $([ "$want" = shown ] && echo installed || echo not installed))"
fi
