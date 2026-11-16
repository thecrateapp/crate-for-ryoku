#!/usr/bin/env bash
# Crate's look for third-party apps: Obsidian, Firefox and Chrome.
#
#   apps.sh install [opts]    lay the app themes into your home
#   apps.sh uninstall         take back what install laid down, and only that
#   apps.sh status            one line per app
#
# Obsidian: the Crate theme is copied into every vault Obsidian knows
#   (<vault>/.obsidian/themes/Crate). You pick it in Settings > Appearance >
#   Themes; appearance.json is never edited.
# Firefox, opt-in (--firefox-chrome): Crate's userChrome.css/userContent.css
#   replace the profile's chrome/ folder (WhiteSur, say). That folder (or
#   symlink) is moved aside to chrome.before-crate and moved back on uninstall.
# Firefox theme add-on, opt-in (--firefox-theme): opens the signed add-on (or
#   its addons.mozilla.org page) in Firefox, which asks before installing.
#
# Everything installed is recorded under $STATE/apps with checksums, so
# uninstall removes only files that are still exactly what it put there.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
APPS=${CRATE_APPS_DIR:-$HERE/apps}
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/crate-for-ryoku
REC=$STATE/apps
FIREFOX_ID=crate-theme@cratemusic.app
AMO_URL=https://addons.mozilla.org/firefox/addon/crate-theme/
MARK='// crate-for-ryoku: userChrome.css and userContent.css'

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<EOF
usage: apps.sh install [--no-obsidian] [--firefox-chrome] [--firefox-theme]
                       [--firefox-profile DIR]...
       apps.sh uninstall
       apps.sh status
  --no-obsidian        do not copy the Obsidian theme into your vaults
  --firefox-chrome     replace each Firefox profile's chrome/ folder with
                       Crate's userChrome.css (the old one is kept and restored)
  --firefox-theme      open the Crate theme add-on in Firefox to install it
  --firefox-profile D  the profile folder(s) for --firefox-chrome (default: the
                       profile each Firefox install starts with)
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

# ---------- Firefox ----------

# firefox_profiles: the profile each Firefox install starts with ([Install*]
# Default=), else the default profile, else every profile
firefox_profiles() {
  local ini
  for ini in "$CFG/mozilla/firefox/profiles.ini" "$HOME/.mozilla/firefox/profiles.ini"; do
    [ -f "$ini" ] || continue
    python3 - "$ini" <<'PY'
import configparser, os, sys
ini = sys.argv[1]
base = os.path.dirname(ini)
cp = configparser.ConfigParser(interpolation=None, strict=False)
cp.optionxform = str
cp.read(ini)
def full(path, relative=True):
    return os.path.normpath(os.path.join(base, path) if relative else path)
installs = [cp[s]["Default"] for s in cp.sections() if s.startswith("Install") and cp[s].get("Default")]
profiles = [s for s in cp.sections() if s.startswith("Profile") and cp[s].get("Path")]
picked = [full(p) if not os.path.isabs(p) else p for p in installs]
if not picked:
    picked = [full(cp[s]["Path"], cp[s].get("IsRelative", "1") == "1") for s in profiles if cp[s].get("Default") == "1"]
if not picked:
    picked = [full(cp[s]["Path"], cp[s].get("IsRelative", "1") == "1") for s in profiles]
seen = set()
for p in picked:
    if p not in seen and os.path.isdir(p):
        seen.add(p)
        print(p)
PY
  done
}

# write_chrome_marker DIR: the checksums of the files we put in DIR/chrome
write_chrome_marker() {
  (cd "$1/chrome" && find . -type f ! -name .crate-for-ryoku -print0 | sort -z | xargs -0 sha256sum) > "$1/chrome/.crate-for-ryoku"
}

chrome_is_ours_unchanged() {
  [ -d "$1/chrome" ] && [ ! -L "$1/chrome" ] && [ -f "$1/chrome/.crate-for-ryoku" ] || return 1
  local now
  now=$(cd "$1/chrome" && find . -type f ! -name .crate-for-ryoku -print0 | sort -z | xargs -0 sha256sum)
  [ "$now" = "$(cat "$1/chrome/.crate-for-ryoku")" ]
}

firefox_chrome_install() {
  local src=$APPS/firefox/chrome prof added
  [ -f "$src/userChrome.css" ] || { warn "no Firefox userChrome.css in $src"; return 0; }
  mkdir -p "$REC"
  touch "$REC/firefox-chrome.list"
  local profiles=("$@")
  if [ ${#profiles[@]} -eq 0 ]; then mapfile -t profiles < <(firefox_profiles); fi
  [ ${#profiles[@]} -gt 0 ] || { warn "Firefox: no profile found"; return 0; }
  for prof in "${profiles[@]}"; do
    prof=$(cd "$prof" && pwd) || continue
    if [ -f "$prof/chrome/.crate-for-ryoku" ]; then
      # ours already: refresh the files, keep the backup and the record
      if chrome_is_ours_unchanged "$prof"; then
        cp -a "$src/." "$prof/chrome/"
        write_chrome_marker "$prof"
        say "Firefox: Crate userChrome.css refreshed in $prof"
      else
        warn "Firefox: $prof/chrome has your edits; left as it is"
      fi
      continue
    fi
    if [ -e "$prof/chrome.before-crate" ] || [ -L "$prof/chrome.before-crate" ]; then
      warn "Firefox: $prof/chrome.before-crate already exists; skipping this profile"
      continue
    fi
    if [ -e "$prof/chrome" ] || [ -L "$prof/chrome" ]; then
      # a symlink moves as a link: the folder it points to is never touched
      mv -- "$prof/chrome" "$prof/chrome.before-crate"
      say "Firefox: your chrome/ is kept as $prof/chrome.before-crate"
    fi
    mkdir -p "$prof/chrome"
    cp -a "$src/." "$prof/chrome/"
    write_chrome_marker "$prof"
    added=0
    if ! grep -qs '"toolkit.legacyUserProfileCustomizations.stylesheets", *true' "$prof/user.js"; then
      printf '%s\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n' "$MARK" >> "$prof/user.js"
      added=1
    fi
    grep -v -F "$prof	" "$REC/firefox-chrome.list" > "$REC/firefox-chrome.list.tmp" || true
    printf '%s\t%s\n' "$prof" "$added" >> "$REC/firefox-chrome.list.tmp"
    mv "$REC/firefox-chrome.list.tmp" "$REC/firefox-chrome.list"
    say "Firefox: Crate userChrome.css in $prof (restart Firefox to see it)"
  done
}

firefox_chrome_uninstall() {
  [ -f "$REC/firefox-chrome.list" ] || return 0
  local prof added
  while IFS=$'\t' read -r prof added; do
    [ -n "$prof" ] && [ -d "$prof" ] || continue
    if [ -f "$prof/chrome/.crate-for-ryoku" ]; then
      if chrome_is_ours_unchanged "$prof"; then
        rm -r -- "$prof/chrome"
      else
        local aside
        aside=$prof/chrome.crate-edited-$(date +%Y%m%d-%H%M%S)
        mv -- "$prof/chrome" "$aside"
        warn "Firefox: Crate's chrome/ had edits; kept as $aside"
      fi
    fi
    if [ -e "$prof/chrome.before-crate" ] || [ -L "$prof/chrome.before-crate" ]; then
      if [ -e "$prof/chrome" ] || [ -L "$prof/chrome" ]; then
        warn "Firefox: $prof/chrome exists; your old one stays at chrome.before-crate"
      else
        mv -- "$prof/chrome.before-crate" "$prof/chrome"
        say "Firefox: restored your chrome/ in $prof"
      fi
    fi
    if [ "$added" = 1 ] && [ -f "$prof/user.js" ]; then
      python3 - "$prof/user.js" "$MARK" <<'PY'
import sys
path, mark = sys.argv[1], sys.argv[2]
lines = open(path).read().split("\n")
out, skip = [], False
for line in lines:
    if line == mark:
        skip = True
        continue
    if skip and line.startswith('user_pref("toolkit.legacyUserProfileCustomizations.stylesheets"'):
        skip = False
        continue
    skip = False
    out.append(line)
open(path, "w").write("\n".join(out))
PY
    fi
  done < "$REC/firefox-chrome.list"
  rm -f -- "$REC/firefox-chrome.list"
}

firefox_theme_install() {
  local xpi
  xpi=$(ls "$APPS"/firefox/signed/*.xpi 2>/dev/null | head -1 || true)
  command -v firefox >/dev/null || { warn "Firefox is not installed"; return 0; }
  if [ -n "$xpi" ]; then
    say "Firefox: opening the signed Crate theme ($xpi); confirm the install in Firefox"
    firefox "$xpi" >/dev/null 2>&1 &
  else
    say "Firefox: opening the Crate theme on addons.mozilla.org ($AMO_URL)"
    firefox "$AMO_URL" >/dev/null 2>&1 &
  fi
}

firefox_theme_present() {
  local prof
  while IFS= read -r prof; do
    python3 - "$prof/extensions.json" "$FIREFOX_ID" <<'PY' && return 0
import json, sys
try:
    addons = json.load(open(sys.argv[1])).get("addons", [])
except (OSError, ValueError):
    sys.exit(1)
sys.exit(0 if any(a.get("id") == sys.argv[2] for a in addons) else 1)
PY
  done < <(firefox_profiles)
  return 1
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
  local ff=0
  [ -f "$REC/firefox-chrome.list" ] && ff=$(grep -c . "$REC/firefox-chrome.list" || true)
  printf '  %-22s %s\n' "Firefox userChrome" "$([ "$ff" -gt 0 ] && echo "yes ($ff profile(s))" || echo no)"
  printf '  %-22s %s\n' "Firefox theme add-on" "$(firefox_theme_present && echo yes || echo no)"
}

cmd=${1:-help}; shift || true
case $cmd in
  install)
    OBSIDIAN=1 FFCHROME=0 FFTHEME=0 PROFILES=()
    while [ $# -gt 0 ]; do
      case $1 in
        --no-obsidian) OBSIDIAN=0 ;;
        --firefox-chrome) FFCHROME=1 ;;
        --firefox-theme) FFTHEME=1 ;;
        --firefox-profile) shift; PROFILES+=("${1:?--firefox-profile needs a folder}") ;;
        --firefox-profile=*) PROFILES+=("${1#*=}") ;;
        -h|--help) usage; exit 0 ;;
        *) echo "apps.sh: unknown option $1" >&2; usage >&2; exit 2 ;;
      esac
      shift
    done
    [ "$OBSIDIAN" = 1 ] && obsidian_install
    [ "$FFCHROME" = 1 ] && firefox_chrome_install ${PROFILES[@]+"${PROFILES[@]}"}
    [ "$FFTHEME" = 1 ] && firefox_theme_install
    exit 0 ;;
  uninstall)
    # CRATE_APPS_ONLY=firefox: the look only (uninstall.sh --keep-files)
    [ "${CRATE_APPS_ONLY:-}" = firefox ] || obsidian_uninstall
    firefox_chrome_uninstall
    exit 0 ;;
  status) status ;;
  -h|--help|help) usage ;;
  *) echo "apps.sh: unknown command $cmd" >&2; usage >&2; exit 2 ;;
esac
