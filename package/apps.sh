#!/usr/bin/env bash
# Crate's look for third-party apps: Obsidian, Firefox and Chrome. Each app is
# detected on its own and skipped quietly when it is not there.
#
#   apps.sh install [opts]          lay the app themes into your home and turn them on
#   apps.sh uninstall [--look-only] take back what install laid down, and only that
#   apps.sh status                  one line per app
#
# Obsidian (found through the vaults in ~/.config/obsidian/obsidian.json): the
#   Crate theme is copied into each vault (<vault>/.obsidian/themes/Crate) and
#   selected there ("cssTheme": "Crate" in appearance.json, every other key
#   kept). The vault's previous cssTheme is recorded and put back on uninstall,
#   unless you have picked another theme since. Ryoku's palette snippet
#   (snippets/ryoku.css) is turned off where Crate is selected, as Ryoku's own
#   doctor does for any vault with a theme of its own, and back on with the
#   previous theme. An open vault shows the change once it is reopened.
# Firefox (found through profiles.ini): Crate's userChrome.css/userContent.css
#   replace the profile's chrome/ folder (WhiteSur, say). That folder (or
#   symlink) is moved aside to chrome.before-crate and moved back on uninstall.
#   Firefox reads them at start: restart it. --no-firefox leaves Firefox alone.
# Firefox theme add-on, opt-in (--firefox-theme): opens the signed add-on (or
#   its addons.mozilla.org page) in Firefox, which asks before installing.
# Chrome: the crate-for-ryoku package offers the theme to every user (an
#   external-extension file for Google Chrome and Chromium); nothing per user,
#   so only status reports it.
#
# Everything installed is recorded under $STATE/apps with checksums, so
# uninstall removes only files that are still exactly what it put there.
# --look-only (uninstall.sh --keep-files) puts the looks back and keeps the
# Obsidian theme copies.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
APPS=${CRATE_APPS_DIR:-$HERE/apps}
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/crate-for-ryoku
REC=$STATE/apps
# where the package's system files live (a test points this at a fake root)
SYSROOT=${CRATE_SYSTEM_ROOT:-}
FIREFOX_ID=crate-theme@cratemusic.app
RYOKU_THEME_ID=ryoku-theme@ryoku.arch
AMO_URL=https://addons.mozilla.org/firefox/addon/crate-theme/
CHROME_ID=jddiejdibphncbpfehopofclalbeghbc
CHROME_CRX=/usr/share/crate-for-ryoku/chrome/crate-theme.crx
CHROME_EXT_DIRS="/usr/share/google-chrome/extensions /usr/share/chromium/extensions /etc/chromium/extensions"
MARK='// crate-for-ryoku: userChrome.css and userContent.css'

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<EOF
usage: apps.sh install [--no-obsidian] [--no-firefox] [--firefox-theme]
                       [--firefox-profile DIR]...
       apps.sh uninstall [--look-only]
       apps.sh status
  --no-obsidian        leave your Obsidian vaults alone
  --no-firefox         leave your Firefox profiles alone (by default each
                       profile's chrome/ folder gets Crate's userChrome.css;
                       the old one is kept and restored by uninstall)
  --firefox-theme      open the Crate theme add-on in Firefox to install it
  --firefox-profile D  the profile folder(s) to theme (default: the profile
                       each Firefox install starts with)
  --look-only          uninstall: put the looks back, keep the theme files
EOF
}

sha() { sha256sum "$1" | cut -d' ' -f1; }

# ---------- Obsidian ----------

obsidian_present() { command -v obsidian >/dev/null || [ -f "$CFG/obsidian/obsidian.json" ]; }

# obsidian_vaults: the existing vault folders Obsidian has registered
obsidian_vaults() {
  local reg=$CFG/obsidian/obsidian.json
  [ -f "$reg" ] || return 0
  python3 - "$reg" <<'PY'
import json, os, sys
try:
    vaults = json.load(open(sys.argv[1])).get("vaults", {})
except (OSError, ValueError, AttributeError):
    sys.exit(0)
for v in vaults.values():
    p = (v or {}).get("path", "").strip() if isinstance(v, dict) else ""
    if p and os.path.isdir(os.path.join(p, ".obsidian")):
        print(p)
PY
}

# obsidian_appearance VAULT: 1 when Ryoku's palette snippet is enabled (else
# 0), a tab, and the vault's cssTheme (empty for Obsidian's default)
obsidian_appearance() {
  python3 -c 'import json,sys
try: d=json.load(open(sys.argv[1])); d=d if isinstance(d,dict) else {}
except Exception: d={}
s=d.get("enabledCssSnippets")
print("%d\t%s" % (isinstance(s,list) and "ryoku" in s, d.get("cssTheme") or ""))' "$1/.obsidian/appearance.json" 2>/dev/null
}
obsidian_css_theme() { obsidian_appearance "$1" | cut -f2; }

# obsidian_select VAULT: select Crate in VAULT's appearance.json, once. The
# first time records the previous cssTheme (JSON, or - when there was none),
# whether the file was created and whether Ryoku's snippet was turned off.
obsidian_select() {
  local vault=$1 file=$1/.obsidian/appearance.json line
  touch "$REC/obsidian-appearance.list"
  if grep -q -F "$file	" "$REC/obsidian-appearance.list"; then
    # selected by an earlier install: a theme you picked since stays
    local cur
    cur=$(obsidian_css_theme "$vault")
    [ "$cur" = Crate ] || say "Obsidian: $vault uses ${cur:-the default theme} since; left as it is"
    return 0
  fi
  if ! line=$(python3 - "$file" <<'PY'
import json, os, sys
path = sys.argv[1]
created = not os.path.exists(path)
doc = {}
if not created:
    try:
        doc = json.load(open(path))
    except (OSError, ValueError):
        sys.exit(3)
    if not isinstance(doc, dict):
        sys.exit(3)
prev = json.dumps(doc["cssTheme"]) if "cssTheme" in doc else "-"
doc["cssTheme"] = "Crate"
# Ryoku's palette snippet outranks any theme; its doctor turns it off in a
# vault that names a cssTheme, and so does this
snippets = doc.get("enabledCssSnippets")
dropped = 0
if isinstance(snippets, list) and "ryoku" in snippets:
    doc["enabledCssSnippets"] = [s for s in snippets if s != "ryoku"]
    dropped = 1
tmp = path + ".crate-tmp"
with open(tmp, "w") as f:
    json.dump(doc, f, indent=2)
os.replace(tmp, path)
print(f"{prev}\t{int(created)}\t{dropped}")
PY
  ); then
    warn "Obsidian: $file is not valid JSON; Crate is there but not selected"
    return 0
  fi
  printf '%s\t%s\n' "$file" "$line" >> "$REC/obsidian-appearance.list"
}

obsidian_install() {
  local src=$APPS/obsidian/Crate n=0 sel=0 vault dest
  [ -f "$src/theme.css" ] || { warn "no Obsidian theme in $src"; return 0; }
  obsidian_present || return 0
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
    obsidian_select "$vault"
    [ "$(obsidian_css_theme "$vault")" = Crate ] && sel=$((sel + 1))
  done < <(obsidian_vaults)
  if [ "$n" -gt 0 ]; then
    say "Obsidian: Crate theme in $n vault(s), selected in $sel (an open vault shows it once you reopen it)"
  else
    say "Obsidian: no vaults yet; skipped"
  fi
}

# obsidian_unselect: each vault where install selected Crate gets its previous
# theme back, as long as Crate is still the one selected
obsidian_unselect() {
  [ -f "$REC/obsidian-appearance.list" ] || return 0
  local file prev created dropped out
  while IFS=$'\t' read -r file prev created dropped; do
    [ -n "$file" ] && [ -f "$file" ] || continue
    out=$(python3 - "$file" "$prev" "$created" "$dropped" <<'PY'
import json, os, sys
path, prev, created, dropped = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4] == "1"
try:
    doc = json.load(open(path))
except (OSError, ValueError):
    print("unreadable")
    sys.exit(0)
if not isinstance(doc, dict) or doc.get("cssTheme") != "Crate":
    print("changed")
    sys.exit(0)
if prev == "-":
    del doc["cssTheme"]
else:
    doc["cssTheme"] = json.loads(prev)
snippets = doc.get("enabledCssSnippets")
if dropped and not (doc.get("cssTheme") or "").strip():
    if not isinstance(snippets, list):
        snippets = []
    if "ryoku" not in snippets:
        doc["enabledCssSnippets"] = snippets + ["ryoku"]
if created and not doc:
    os.remove(path)
    print("removed")
    sys.exit(0)
tmp = path + ".crate-tmp"
with open(tmp, "w") as f:
    json.dump(doc, f, indent=2)
os.replace(tmp, path)
print("restored")
PY
    )
    case $out in
      restored|removed) say "Obsidian: previous theme back in ${file%/.obsidian/appearance.json}" ;;
      changed) say "Obsidian: ${file%/.obsidian/appearance.json} has another theme selected now; left as it is" ;;
      *) warn "Obsidian: could not read $file; left as it is" ;;
    esac
  done < "$REC/obsidian-appearance.list"
  rm -f -- "$REC/obsidian-appearance.list"
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

firefox_present() { command -v firefox >/dev/null || [ -f "$CFG/mozilla/firefox/profiles.ini" ] || [ -f "$HOME/.mozilla/firefox/profiles.ini" ]; }

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
try:
    cp.read(ini)
except configparser.Error:
    sys.exit(0)
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
  local src=$APPS/firefox/chrome prof added n=0
  [ -f "$src/userChrome.css" ] || { warn "no Firefox userChrome.css in $src"; return 0; }
  local profiles=("$@")
  if [ ${#profiles[@]} -eq 0 ]; then mapfile -t profiles < <(firefox_profiles); fi
  if [ ${#profiles[@]} -eq 0 ]; then
    firefox_present && say "Firefox: no profile yet (start Firefox once, then install again); skipped"
    return 0
  fi
  mkdir -p "$REC"
  touch "$REC/firefox-chrome.list"
  for prof in "${profiles[@]}"; do
    prof=$(cd "$prof" && pwd) || continue
    if [ -f "$prof/chrome/.crate-for-ryoku" ]; then
      # ours already: refresh the files, keep the backup and the record
      if chrome_is_ours_unchanged "$prof"; then
        cp -a "$src/." "$prof/chrome/"
        write_chrome_marker "$prof"
        say "Firefox: Crate userChrome.css refreshed in $prof"
        n=$((n + 1))
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
    say "Firefox: Crate userChrome.css in $prof"
    n=$((n + 1))
  done
  if [ "$n" -gt 0 ]; then say "Firefox: restart Firefox to see Crate's look"; fi
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
  command -v firefox >/dev/null || { say "Firefox is not installed; the theme add-on is skipped"; return 0; }
  if [ -n "$xpi" ]; then
    say "Firefox: opening the signed Crate theme ($xpi); confirm the install in Firefox"
    firefox "$xpi" >/dev/null 2>&1 &
  else
    say "Firefox: opening the Crate theme on addons.mozilla.org ($AMO_URL)"
    firefox "$AMO_URL" >/dev/null 2>&1 &
  fi
}

# firefox_has_addon ID: some profile lists the add-on in extensions.json
firefox_has_addon() {
  local prof
  while IFS= read -r prof; do
    python3 - "$prof/extensions.json" "$1" <<'PY' && return 0
import json, sys
try:
    addons = json.load(open(sys.argv[1])).get("addons", [])
except (OSError, ValueError, AttributeError):
    sys.exit(1)
sys.exit(0 if any(a.get("id") == sys.argv[2] and a.get("active", True) for a in addons) else 1)
PY
  done < <(firefox_profiles)
  return 1
}

# ---------- Chrome ----------

chrome_browsers() {
  local b
  for b in google-chrome-stable google-chrome chromium; do
    command -v "$b" >/dev/null && printf '%s ' "$b"
  done
  return 0
}

chrome_package_present() {
  local d
  [ -f "$SYSROOT$CHROME_CRX" ] || return 1
  for d in $CHROME_EXT_DIRS; do [ -f "$SYSROOT$d/$CHROME_ID.json" ] && return 0; done
  return 1
}

# chrome_selected: the profiles (Chrome and Chromium) whose theme is Crate's
chrome_selected() {
  python3 - "$CFG" "$CHROME_ID" <<'PY'
import glob, json, os, sys
cfg, want = sys.argv[1], sys.argv[2]
n = 0
for prefs in glob.glob(os.path.join(cfg, "google-chrome*", "*", "Preferences")) + \
             glob.glob(os.path.join(cfg, "chromium", "*", "Preferences")):
    try:
        theme = json.load(open(prefs)).get("extensions", {}).get("theme", {})
    except (OSError, ValueError, AttributeError):
        continue
    if isinstance(theme, dict) and theme.get("id") == want:
        n += 1
print(n)
PY
}

# ---------- commands ----------

status() {
  local line vault total=0 n=0 sel=0 snip=0 css ryoku
  if obsidian_present; then
    while IFS= read -r vault; do
      total=$((total + 1))
      [ -f "$vault/.obsidian/themes/Crate/theme.css" ] && n=$((n + 1))
      IFS=$'\t' read -r ryoku css < <(obsidian_appearance "$vault")
      if [ "$css" = Crate ]; then
        sel=$((sel + 1))
        [ "$ryoku" = 1 ] && snip=$((snip + 1))
      fi
    done < <(obsidian_vaults)
    line="installed; Crate in $n of $total vault(s), selected in $sel"
    # stock Ryoku's doctor turns its palette snippet back on over any theme
    if [ "$snip" -gt 0 ]; then line="$line (Ryoku's palette snippet is on in $snip and greys it out)"; fi
  else
    line="not installed"
  fi
  printf '  %-22s %s\n' "Obsidian" "$line"

  local prof ff=0 fftotal=0
  if firefox_present; then
    while IFS= read -r prof; do
      fftotal=$((fftotal + 1))
      [ -f "$prof/chrome/.crate-for-ryoku" ] && ff=$((ff + 1))
    done < <(firefox_profiles)
    line="installed; Crate userChrome in $ff of $fftotal profile(s)"
  else
    line="not installed"
  fi
  printf '  %-22s %s\n' "Firefox" "$line"
  if firefox_present; then
    line=$(firefox_has_addon "$FIREFOX_ID" && echo yes || echo no)
    # Ryoku's own browser extension recolours Firefox live over any static theme
    if firefox_has_addon "$RYOKU_THEME_ID"; then
      line="$line (the Ryoku Theme extension recolours Firefox over it)"
    fi
    printf '  %-22s %s\n' "Firefox theme add-on" "$line"
  fi

  local browsers
  browsers=$(chrome_browsers)
  if [ -n "$browsers" ]; then
    line="installed (${browsers% }); "
    if chrome_package_present; then
      line="${line}Crate theme offered by the package, selected in $(chrome_selected) profile(s)"
    else
      line="${line}Crate theme not packaged (the crate-for-ryoku package built with the Chrome key ships it)"
    fi
  else
    line="not installed"
    if chrome_package_present; then line="$line; Crate theme packaged"; fi
  fi
  printf '  %-22s %s\n' "Chrome" "$line"
}

cmd=${1:-help}; shift || true
case $cmd in
  install)
    OBSIDIAN=1 FIREFOX=1 FFTHEME=0 PROFILES=()
    while [ $# -gt 0 ]; do
      case $1 in
        --no-obsidian) OBSIDIAN=0 ;;
        --no-firefox) FIREFOX=0 ;;
        --firefox-chrome) ;;  # the default since 0.7; kept so older command lines still work
        --firefox-theme) FFTHEME=1 ;;
        --firefox-profile) shift; PROFILES+=("${1:?--firefox-profile needs a folder}") ;;
        --firefox-profile=*) PROFILES+=("${1#*=}") ;;
        -h|--help) usage; exit 0 ;;
        *) echo "apps.sh: unknown option $1" >&2; usage >&2; exit 2 ;;
      esac
      shift
    done
    [ "$OBSIDIAN" = 1 ] && obsidian_install
    [ "$FIREFOX" = 1 ] && firefox_chrome_install ${PROFILES[@]+"${PROFILES[@]}"}
    [ "$FFTHEME" = 1 ] && firefox_theme_install
    exit 0 ;;
  uninstall)
    LOOK=0
    # CRATE_APPS_ONLY=firefox: what uninstall.sh --keep-files passed before 0.7
    [ "${CRATE_APPS_ONLY:-}" = firefox ] && LOOK=1
    case ${1:-} in
      --look-only) LOOK=1 ;;
      '') ;;
      *) echo "apps.sh: unknown option $1" >&2; usage >&2; exit 2 ;;
    esac
    obsidian_unselect
    [ "$LOOK" = 1 ] || obsidian_uninstall
    firefox_chrome_uninstall
    exit 0 ;;
  status) status ;;
  -h|--help|help) usage ;;
  *) echo "apps.sh: unknown command $cmd" >&2; usage >&2; exit 2 ;;
esac
