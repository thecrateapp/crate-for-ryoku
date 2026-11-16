#!/usr/bin/env bash
# Crate's look for third-party apps: Obsidian.
#
#   apps.sh install [opts]    lay the app themes into your home
#   apps.sh uninstall         take back what install laid down, and only that
#   apps.sh status            one line per app
#
# Obsidian: the Crate theme is copied into every vault Obsidian knows
#   (<vault>/.obsidian/themes/Crate). You pick it in Settings > Appearance >
#   Themes; appearance.json is never edited.
#
# Everything installed is recorded under $STATE/apps with checksums, so
# uninstall removes only files that are still exactly what it put there.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
APPS=${CRATE_APPS_DIR:-$HERE/apps}
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/crate-for-ryoku
REC=$STATE/apps

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<EOF
usage: apps.sh install [--no-obsidian]
       apps.sh uninstall
       apps.sh status
  --no-obsidian        do not copy the Obsidian theme into your vaults
EOF
}

sha() { sha256sum "$1" | cut -d' ' -f1; }

# ---------- Obsidian ----------

# obsidian_vaults: the existing vault folders Obsidian has registered
obsidian_vaults() {
  local reg=$CFG/obsidian/obsidian.json
  [ -f "$reg" ] || return 0
  python3 - "$reg" <<'PY'
import json, os, sys
try:
    vaults = json.load(open(sys.argv[1])).get("vaults", {})
except (OSError, ValueError):
    sys.exit(0)
for v in vaults.values():
    p = (v or {}).get("path", "").strip() if isinstance(v, dict) else ""
    if p and os.path.isdir(os.path.join(p, ".obsidian")):
        print(p)
PY
}

obsidian_install() {
  local src=$APPS/obsidian/Crate n=0 vault dest
  [ -f "$src/theme.css" ] || { warn "no Obsidian theme in $src"; return 0; }
  mkdir -p "$REC"
  touch "$REC/obsidian.list"
  while IFS= read -r vault; do
    dest=$vault/.obsidian/themes/Crate
    if [ -f "$dest/theme.css" ] && ! grep -qxF "$dest	$(sha "$dest/theme.css")" "$REC/obsidian.list" \
       && ! cmp -s "$src/theme.css" "$dest/theme.css"; then
      # a Crate theme we did not put there (the community store's, an edited copy)
      say "Obsidian: $dest is not ours; left as it is"
      continue
    fi
    mkdir -p "$dest"
    cp "$src/theme.css" "$src/manifest.json" "$dest/"
    grep -v -F "$dest	" "$REC/obsidian.list" > "$REC/obsidian.list.tmp" || true
    printf '%s\t%s\n' "$dest" "$(sha "$dest/theme.css")" >> "$REC/obsidian.list.tmp"
    mv "$REC/obsidian.list.tmp" "$REC/obsidian.list"
    n=$((n + 1))
  done < <(obsidian_vaults)
  if [ "$n" -gt 0 ]; then
    say "Obsidian: Crate theme in $n vault(s) (Settings > Appearance > Themes > Crate)"
  fi
}

obsidian_uninstall() {
  [ -f "$REC/obsidian.list" ] || return 0
  local dest sum
  while IFS=$'\t' read -r dest sum; do
    [ -n "$dest" ] || continue
    if [ ! -f "$dest/theme.css" ]; then continue; fi
    if [ "$(sha "$dest/theme.css")" != "$sum" ]; then
      warn "Obsidian: $dest/theme.css changed since install; left in place"
      continue
    fi
    rm -f -- "$dest/theme.css" "$dest/manifest.json"
    rmdir -- "$dest" 2>/dev/null || true
    say "Obsidian: removed $dest"
  done < "$REC/obsidian.list"
  rm -f -- "$REC/obsidian.list"
}

# ---------- commands ----------

status() {
  local n=0 sel=0 vault total=0 css
  while IFS= read -r vault; do
    total=$((total + 1))
    [ -f "$vault/.obsidian/themes/Crate/theme.css" ] && n=$((n + 1))
    css=$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("cssTheme",""))
except Exception: print("")' "$vault/.obsidian/appearance.json" 2>/dev/null)
    [ "$css" = Crate ] && sel=$((sel + 1))
  done < <(obsidian_vaults)
  printf '  %-22s %s\n' "Obsidian theme" "$n of $total vault(s), selected in $sel"
}

cmd=${1:-help}; shift || true
case $cmd in
  install)
    OBSIDIAN=1
    while [ $# -gt 0 ]; do
      case $1 in
        --no-obsidian) OBSIDIAN=0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "apps.sh: unknown option $1" >&2; usage >&2; exit 2 ;;
      esac
      shift
    done
    [ "$OBSIDIAN" = 1 ] && obsidian_install
    exit 0 ;;
  uninstall)
    obsidian_uninstall
    exit 0 ;;
  status) status ;;
  -h|--help|help) usage ;;
  *) echo "apps.sh: unknown command $cmd" >&2; usage >&2; exit 2 ;;
esac
