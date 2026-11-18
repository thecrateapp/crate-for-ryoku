#!/usr/bin/env bash
# Crate's look for third-party apps: Obsidian, Firefox, Chrome, Zed, lazygit, Neovim, GTK and Text Editor. Each app is
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
usage: apps.sh install [--no-obsidian] [--no-firefox] [--no-zed] [--no-lazygit] [--no-nvim]
                       [--no-gtk] [--no-gtksourceview]
                       [--no-thunderbird] [--no-cursor]
                       [--firefox-theme]
                       [--firefox-profile DIR]...
       apps.sh uninstall [--look-only]
       apps.sh status
  --no-obsidian        leave your Obsidian vaults alone
  --no-zed             leave Zed's theme and settings.json alone
  --no-lazygit         leave lazygit's config.yml alone
  --no-nvim            leave Neovim's plugins folder alone
  --no-gtk             leave GTK's user.css alone
  --no-gtksourceview   leave GtkSourceView and Text Editor's scheme alone
  --no-thunderbird     leave Thunderbird's profiles alone
  --no-cursor          keep the cursor theme you use
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

# ---------- Zed ----------
# Zed (zed on PATH, its user install in ~/.local/zed.app, or ~/.config/zed): the
#   Crate theme goes to ~/.config/zed/themes/crate.json and settings.json gets
#   "Crate" as its dark theme through zed_settings.py, which edits only that value
#   and keeps your comments. Uninstall puts your previous theme back unless you
#   have picked another since. Zed picks both up live.
zed_present() { command -v zed >/dev/null || [ -d "$HOME/.local/zed.app" ] || [ -d "$CFG/zed" ]; }

zed_install() {
  local src=$APPS/zed/crate.json dest=$CFG/zed/themes/crate.json file=$CFG/zed/settings.json out cur
  [ -f "$src" ] || { warn "no Zed theme in $src"; return 0; }
  zed_present || return 0
  mkdir -p "$REC"
  if [ -f "$dest" ] && [ -f "$REC/zed-theme.sha" ] && [ "$(sha "$dest")" != "$(cat "$REC/zed-theme.sha")" ]; then
    say "Zed: $dest changed since install; left as it is"
  elif [ -f "$dest" ] && [ ! -f "$REC/zed-theme.sha" ] && ! cmp -s "$src" "$dest"; then
    say "Zed: $dest is not ours; left as it is"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    sha "$dest" > "$REC/zed-theme.sha"
  fi
  if [ -s "$REC/zed-settings.list" ]; then
    # selected by an earlier install: a theme you picked since stays
    cur=$(python3 "$HERE/zed_settings.py" current "$file")
    if [ "$cur" = Crate ]; then
      say "Zed: Crate theme selected"
    else
      say "Zed: you use ${cur:-the default theme} since; left as it is"
    fi
    return 0
  fi
  if out=$(python3 "$HERE/zed_settings.py" select "$file" Crate); then
    printf '%s\t%s\n' "$file" "$out" > "$REC/zed-settings.list"
    say "Zed: Crate theme selected (Zed picks it up live)"
  else
    warn "Zed: $file is not valid JSON; Crate is there but not selected"
  fi
}

# zed_unselect: the theme install replaced comes back, while Crate is still selected
zed_unselect() {
  [ -s "$REC/zed-settings.list" ] || return 0
  local file mode prev r
  IFS=$'\t' read -r file mode prev < "$REC/zed-settings.list"
  r=$(python3 "$HERE/zed_settings.py" restore "$file" Crate "$mode" "$prev" 2>/dev/null || echo kept)
  if [ "$r" = restored ]; then
    say "Zed: your previous theme is back"
  else
    say "Zed: you use another theme since; left as it is"
  fi
  rm -f -- "$REC/zed-settings.list"
}

zed_uninstall() {
  [ -f "$REC/zed-theme.sha" ] || return 0
  local dest=$CFG/zed/themes/crate.json
  if [ -f "$dest" ] && [ "$(python3 "$HERE/zed_settings.py" current "$CFG/zed/settings.json")" = Crate ]; then
    # settings.json still names Crate: without the file Zed would report a missing theme
    warn "Zed: settings.json still selects Crate; $dest left in place"
  elif [ -f "$dest" ]; then
    if [ "$(sha "$dest")" = "$(cat "$REC/zed-theme.sha")" ]; then
      rm -f -- "$dest"
      rmdir -- "$CFG/zed/themes" "$CFG/zed" 2>/dev/null || true
      say "Zed: removed $dest"
    else
      warn "Zed: $dest changed since install; left in place"
    fi
  fi
  rm -f -- "$REC/zed-theme.sha"
}

# ---------- lazygit ----------
# lazygit: Crate's theme is a config.yml whose first line is LAZYGIT_MARK. It is
#   written only where there is no config.yml, an empty one, or ours; a config of
#   your own is left alone. Uninstall removes ours (or empties it again, if it
#   was an empty file before) unless the marker line is gone.
LAZYGIT_MARK='# crate-for-ryoku: lazygit'
lazygit_present() { command -v lazygit >/dev/null; }
lazygit_ours() { [ -f "$1" ] && [ "$(head -n 1 "$1")" = "$LAZYGIT_MARK" ]; }

lazygit_install() {
  local src=$APPS/lazygit/config.yml dest=$CFG/lazygit/config.yml
  [ -f "$src" ] || { warn "no lazygit theme in $src"; return 0; }
  lazygit_present || return 0
  mkdir -p "$REC"
  if [ ! -e "$dest" ] || [ ! -s "$dest" ]; then
    # remember what was there the first time, so uninstall can put it back
    [ -f "$REC/lazygit.state" ] || { [ -e "$dest" ] && echo empty || echo absent; } > "$REC/lazygit.state"
  elif ! lazygit_ours "$dest"; then
    say "lazygit: you have your own config.yml; left as it is"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  say "lazygit: Crate theme ($dest)"
}

lazygit_uninstall() {
  [ -f "$REC/lazygit.state" ] || return 0
  local dest=$CFG/lazygit/config.yml
  if lazygit_ours "$dest"; then
    if [ "$(cat "$REC/lazygit.state")" = empty ]; then
      : > "$dest"
    else
      rm -f -- "$dest"
      rmdir -- "$CFG/lazygit" 2>/dev/null || true
    fi
    say "lazygit: Crate theme removed"
  elif [ -f "$dest" ]; then
    say "lazygit: $dest is yours now; left as it is"
  fi
  rm -f -- "$REC/lazygit.state"
}

# ---------- Neovim ----------
# Neovim with a lazy.nvim config (LazyVim, as Ryoku ships): Crate's sober syntax
#   goes to ~/.config/nvim/lua/plugins/crate.lua, first line NVIM_MARK, as an
#   on_highlights over Ryoku's tokyonight. Written only where there is no
#   crate.lua or ours; uninstall removes ours. Takes effect at nvim's next start.
NVIM_MARK='-- crate-for-ryoku: neovim'
nvim_present() { command -v nvim >/dev/null; }
nvim_ours() { [ -f "$1" ] && [ "$(head -n 1 "$1")" = "$NVIM_MARK" ]; }

nvim_install() {
  local src=$APPS/nvim/crate.lua dir=$CFG/nvim/lua/plugins
  [ -f "$src" ] || { warn "no Neovim syntax in $src"; return 0; }
  nvim_present || return 0
  if [ ! -d "$dir" ]; then
    say "Neovim: no lazy.nvim plugins folder ($dir); skipped"
    return 0
  fi
  if [ -e "$dir/crate.lua" ] && ! nvim_ours "$dir/crate.lua"; then
    say "Neovim: you have your own $dir/crate.lua; left as it is"
    return 0
  fi
  cp "$src" "$dir/crate.lua"
  say "Neovim: Crate syntax ($dir/crate.lua, from nvim's next start)"
}

nvim_uninstall() {
  local f=$CFG/nvim/lua/plugins/crate.lua
  if nvim_ours "$f"; then
    rm -f -- "$f"
    say "Neovim: Crate syntax removed"
  fi
}

# ---------- GTK ----------
# GTK 4 / libadwaita and GTK 3 apps: Crate's corners, hairlines and surfaces go
#   to ~/.config/gtk-{4,3}.0/crate.css, loaded by a marked line in user.css,
#   which Ryoku's gtk.css imports last (the fork's user include). Your own lines
#   in user.css stay; uninstall takes back the line, and crate.css while it is
#   unchanged. GTK apps read it at start.
GTK_LINE='@import url("crate.css"); /* crate-for-ryoku */'
DATA=${XDG_DATA_HOME:-$HOME/.local/share}

gtk_install() {
  local ver src dir dest user n=0
  for ver in 4.0 3.0; do
    # only where Ryoku renders a gtk.css: that is what imports user.css
    [ -f "$CFG/gtk-$ver/gtk.css" ] || continue
    src=$APPS/gtk/crate.css
    [ "$ver" = 3.0 ] && src=$APPS/gtk/crate-gtk3.css
    [ -f "$src" ] || { warn "no GTK stylesheet in $src"; return 0; }
    dir=$CFG/gtk-$ver dest=$dir/crate.css user=$dir/user.css
    mkdir -p "$dir" "$REC"
    if [ -f "$dest" ] && ! { [ -f "$REC/gtk-$ver.sha" ] && [ "$(sha "$dest")" = "$(cat "$REC/gtk-$ver.sha")" ]; } \
       && ! cmp -s "$src" "$dest"; then
      say "GTK $ver: $dest is not ours; left as it is"
      continue
    fi
    cp "$src" "$dest"
    sha "$dest" > "$REC/gtk-$ver.sha"
    if [ ! -e "$user" ]; then
      : > "$REC/gtk-$ver.created"
      printf '%s\n' "$GTK_LINE" > "$user"
    elif ! grep -qxF "$GTK_LINE" "$user"; then
      if [ -s "$user" ] && [ -n "$(tail -c 1 "$user")" ]; then echo >> "$user"; fi
      printf '%s\n' "$GTK_LINE" >> "$user"
    fi
    n=$((n + 1))
  done
  [ "$n" -gt 0 ] || return 0
  say "GTK: Crate's corners and hairlines (apps show them once restarted)"
  if ! grep -qF 'url("user.css")' "$CFG/gtk-4.0/gtk.css" 2>/dev/null; then
    warn "GTK: this Ryoku's gtk.css does not load user.css yet; Crate's CSS waits for it"
  fi
}

gtk_uninstall() {
  local ver dir user
  for ver in 4.0 3.0; do
    dir=$CFG/gtk-$ver user=$dir/user.css
    if [ -f "$user" ] && grep -qxF "$GTK_LINE" "$user"; then
      grep -vxF "$GTK_LINE" "$user" > "$user.crate-tmp" || true
      # written back through the file, so a symlinked user.css (dotfiles) stays a link
      cat "$user.crate-tmp" > "$user"
      rm -f -- "$user.crate-tmp"
      if [ -f "$REC/gtk-$ver.created" ] && [ ! -s "$user" ]; then rm -f -- "$user"; fi
    fi
    if [ -f "$REC/gtk-$ver.sha" ] && [ -f "$dir/crate.css" ]; then
      if [ "$(sha "$dir/crate.css")" = "$(cat "$REC/gtk-$ver.sha")" ]; then
        rm -f -- "$dir/crate.css"
      else
        warn "GTK $ver: $dir/crate.css changed since install; left in place"
      fi
    fi
    rm -f -- "$REC/gtk-$ver.sha" "$REC/gtk-$ver.created"
  done
}

# ---------- Text Editor (GtkSourceView) ----------
# The Crate GtkSourceView 5 scheme goes to ~/.local/share/gtksourceview-5/styles
#   for every app built on it; GNOME Text Editor, when installed, gets it as its
#   style-scheme once (the old one recorded and put back by uninstall while
#   Crate is still selected). Text Editor follows the setting live.
TE_SCHEMA=org.gnome.TextEditor
texteditor_present() { command -v gnome-text-editor >/dev/null; }
texteditor_scheme() {
  local v
  v=$(gsettings get "$TE_SCHEMA" style-scheme 2>/dev/null) || return 0
  printf '%s\n' "$v" | sed "s/'//g"
}

gtksourceview_install() {
  local src=$APPS/gtksourceview/crate.xml dest=$DATA/gtksourceview-5/styles/crate.xml cur
  [ -f "$src" ] || { warn "no GtkSourceView scheme in $src"; return 0; }
  mkdir -p "$REC"
  if [ -f "$dest" ] && ! { [ -f "$REC/gtksourceview.sha" ] && [ "$(sha "$dest")" = "$(cat "$REC/gtksourceview.sha")" ]; } \
     && ! cmp -s "$src" "$dest"; then
    say "GtkSourceView: $dest is not ours; left as it is"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    sha "$dest" > "$REC/gtksourceview.sha"
  fi
  texteditor_present && command -v gsettings >/dev/null || return 0
  if [ -f "$REC/texteditor.scheme" ]; then
    cur=$(texteditor_scheme)
    [ "$cur" = crate ] || say "Text Editor: you use ${cur:-another scheme} since; left as it is"
    return 0
  fi
  local prev
  # the record is written only once gsettings has answered and taken the change,
  # so a run where it fails is simply tried again by the next install
  if ! prev=$(gsettings get "$TE_SCHEMA" style-scheme 2>/dev/null) \
     || ! gsettings set "$TE_SCHEMA" style-scheme crate 2>/dev/null; then
    warn "Text Editor: gsettings did not answer; Crate scheme not selected"
    return 0
  fi
  printf '%s\n' "$prev" | sed "s/'//g" > "$REC/texteditor.scheme"
  say "Text Editor: Crate scheme selected"
}

gtksourceview_uninstall() {
  local dest=$DATA/gtksourceview-5/styles/crate.xml prev
  if [ -f "$REC/texteditor.scheme" ]; then
    prev=$(cat "$REC/texteditor.scheme")
    if command -v gsettings >/dev/null && [ "$(texteditor_scheme)" = crate ]; then
      gsettings set "$TE_SCHEMA" style-scheme "${prev:-Adwaita}"
      say "Text Editor: ${prev:-Adwaita} is back"
    fi
    rm -f -- "$REC/texteditor.scheme"
  fi
  if [ -f "$REC/gtksourceview.sha" ] && [ -f "$dest" ]; then
    if [ "$(sha "$dest")" = "$(cat "$REC/gtksourceview.sha")" ]; then
      rm -f -- "$dest"
      rmdir -- "$(dirname "$dest")" "$DATA/gtksourceview-5" 2>/dev/null || true
    else
      warn "GtkSourceView: $dest changed since install; left in place"
    fi
  fi
  rm -f -- "$REC/gtksourceview.sha"
}

# ---------- Firefox ----------

firefox_present() { command -v firefox >/dev/null || [ -f "$CFG/mozilla/firefox/profiles.ini" ] || [ -f "$HOME/.mozilla/firefox/profiles.ini" ]; }

# firefox_profiles: the profile each Firefox install starts with ([Install*]
# Default=), else the default profile, else every profile
firefox_profiles() { mozilla_profiles "$CFG/mozilla/firefox/profiles.ini" "$HOME/.mozilla/firefox/profiles.ini"; }

# mozilla_profiles INI...: the profile each install of a Mozilla app starts with
# (else the default profile, else every profile), one folder per line
mozilla_profiles() {
  local ini
  for ini in "$@"; do
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

# mozilla_chrome_install LABEL SRC RECORD PROFILE...: Crate's chrome/ into each
# profile of a Mozilla app (Firefox, Thunderbird); the old chrome/ moves aside to
# chrome.before-crate, the stylesheets pref goes into user.js, marked
mozilla_chrome_install() {
  local label=$1 src=$2 record=$3 prof added n=0
  shift 3
  [ -f "$src/userChrome.css" ] || { warn "no $label userChrome.css in $src"; return 0; }
  local profiles=("$@")
  mkdir -p "$REC"
  touch "$REC/$record"
  for prof in "${profiles[@]}"; do
    prof=$(cd "$prof" && pwd) || continue
    if [ -f "$prof/chrome/.crate-for-ryoku" ]; then
      # ours already: refresh the files, keep the backup and the record
      if chrome_is_ours_unchanged "$prof"; then
        cp -a "$src/." "$prof/chrome/"
        write_chrome_marker "$prof"
        say "$label: Crate userChrome.css refreshed in $prof"
        n=$((n + 1))
      else
        warn "$label: $prof/chrome has your edits; left as it is"
      fi
      continue
    fi
    if [ -e "$prof/chrome.before-crate" ] || [ -L "$prof/chrome.before-crate" ]; then
      warn "$label: $prof/chrome.before-crate already exists; skipping this profile"
      continue
    fi
    if [ -e "$prof/chrome" ] || [ -L "$prof/chrome" ]; then
      # a symlink moves as a link: the folder it points to is never touched
      mv -- "$prof/chrome" "$prof/chrome.before-crate"
      say "$label: your chrome/ is kept as $prof/chrome.before-crate"
    fi
    mkdir -p "$prof/chrome"
    cp -a "$src/." "$prof/chrome/"
    write_chrome_marker "$prof"
    added=0
    if ! grep -qs '"toolkit.legacyUserProfileCustomizations.stylesheets", *true' "$prof/user.js"; then
      printf '%s\nuser_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n' "$MARK" >> "$prof/user.js"
      added=1
    fi
    grep -v -F "$prof	" "$REC/$record" > "$REC/$record.tmp" || true
    printf '%s\t%s\n' "$prof" "$added" >> "$REC/$record.tmp"
    mv "$REC/$record.tmp" "$REC/$record"
    say "$label: Crate userChrome.css in $prof"
    n=$((n + 1))
  done
  if [ "$n" -gt 0 ]; then say "$label: restart $label to see Crate's look"; fi
}

mozilla_chrome_uninstall() {
  local label=$1 record=$2 prof added
  [ -f "$REC/$record" ] || return 0
  while IFS=$'\t' read -r prof added; do
    [ -n "$prof" ] && [ -d "$prof" ] || continue
    if [ -f "$prof/chrome/.crate-for-ryoku" ]; then
      if chrome_is_ours_unchanged "$prof"; then
        rm -r -- "$prof/chrome"
      else
        local aside
        aside=$prof/chrome.crate-edited-$(date +%Y%m%d-%H%M%S)
        mv -- "$prof/chrome" "$aside"
        warn "$label: Crate's chrome/ had edits; kept as $aside"
      fi
    fi
    if [ -e "$prof/chrome.before-crate" ] || [ -L "$prof/chrome.before-crate" ]; then
      if [ -e "$prof/chrome" ] || [ -L "$prof/chrome" ]; then
        warn "$label: $prof/chrome exists; your old one stays at chrome.before-crate"
      else
        mv -- "$prof/chrome.before-crate" "$prof/chrome"
        say "$label: restored your chrome/ in $prof"
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
  done < "$REC/$record"
  rm -f -- "$REC/$record"
}

firefox_chrome_install() {
  local profiles=("$@")
  [ -f "$APPS/firefox/chrome/userChrome.css" ] || { warn "no Firefox userChrome.css in $APPS/firefox/chrome"; return 0; }
  if [ ${#profiles[@]} -eq 0 ]; then mapfile -t profiles < <(firefox_profiles); fi
  if [ ${#profiles[@]} -eq 0 ]; then
    firefox_present && say "Firefox: no profile yet (start Firefox once, then install again); skipped"
    return 0
  fi
  mozilla_chrome_install Firefox "$APPS/firefox/chrome" firefox-chrome.list "${profiles[@]}"
}

firefox_chrome_uninstall() { mozilla_chrome_uninstall Firefox firefox-chrome.list; }

# ---------- Thunderbird ----------
# Thunderbird (~/.thunderbird/profiles.ini): Crate's userChrome.css through the
#   same chrome/ handling as Firefox (yours moved aside to chrome.before-crate and
#   back, the stylesheets pref in user.js, marked). Restart Thunderbird to see it.
thunderbird_present() { command -v thunderbird >/dev/null || [ -f "$HOME/.thunderbird/profiles.ini" ]; }
thunderbird_profiles() { mozilla_profiles "$HOME/.thunderbird/profiles.ini"; }

thunderbird_chrome_install() {
  local profiles=()
  [ -f "$APPS/thunderbird/chrome/userChrome.css" ] || { warn "no Thunderbird userChrome.css in $APPS/thunderbird/chrome"; return 0; }
  thunderbird_present || return 0
  mapfile -t profiles < <(thunderbird_profiles)
  if [ ${#profiles[@]} -eq 0 ]; then
    say "Thunderbird: no profile yet (start Thunderbird once, then install again); skipped"
    return 0
  fi
  mozilla_chrome_install Thunderbird "$APPS/thunderbird/chrome" thunderbird-chrome.list "${profiles[@]}"
}

thunderbird_chrome_uninstall() { mozilla_chrome_uninstall Thunderbird thunderbird-chrome.list; }

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

  if zed_present; then
    if [ -f "$CFG/zed/themes/crate.json" ] && [ "$(python3 "$HERE/zed_settings.py" current "$CFG/zed/settings.json")" = Crate ]; then
      line="installed; Crate selected"
    else
      line="installed; Crate not selected"
    fi
  else
    line="not installed"
  fi
  printf '  %-22s %s\n' "Zed" "$line"

  if lazygit_present; then
    if lazygit_ours "$CFG/lazygit/config.yml"; then
      line="Crate theme"
    elif [ -s "$CFG/lazygit/config.yml" ]; then
      line="your own config.yml"
    else
      line="installed; no theme"
    fi
  else
    line="not installed"
  fi
  printf '  %-22s %s\n' "lazygit" "$line"

  if nvim_present; then
    if nvim_ours "$CFG/nvim/lua/plugins/crate.lua"; then
      line="Crate syntax"
    elif [ -e "$CFG/nvim/lua/plugins/crate.lua" ]; then
      line="your own crate.lua"
    elif [ -d "$CFG/nvim/lua/plugins" ]; then
      line="installed; no Crate syntax"
    else
      line="installed; no lazy.nvim plugins folder"
    fi
  else
    line="not installed"
  fi
  printf '  %-22s %s\n' "Neovim" "$line"

  if grep -qxF "$GTK_LINE" "$CFG/gtk-4.0/user.css" 2>/dev/null && [ -f "$CFG/gtk-4.0/crate.css" ]; then
    if grep -qF 'url("user.css")' "$CFG/gtk-4.0/gtk.css" 2>/dev/null; then
      line="Crate CSS"
    else
      line="Crate CSS, but this Ryoku does not load user.css"
    fi
  else
    line="no"
  fi
  printf '  %-22s %s\n' "GTK" "$line"

  if texteditor_present; then
    if [ -f "$DATA/gtksourceview-5/styles/crate.xml" ] && [ "$(texteditor_scheme)" = crate ]; then
      line="Crate scheme selected"
    else
      line="installed; Crate not selected"
    fi
  else
    line="not installed"
  fi
  printf '  %-22s %s\n' "Text Editor" "$line"

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

  local tb=0 tbtotal=0
  if thunderbird_present; then
    while IFS= read -r prof; do
      tbtotal=$((tbtotal + 1))
      [ -f "$prof/chrome/.crate-for-ryoku" ] && tb=$((tb + 1))
    done < <(thunderbird_profiles)
    if [ "$tbtotal" -gt 0 ]; then
      line="installed; Crate userChrome in $tb of $tbtotal profile(s)"
    else
      line="installed; no profile"
    fi
  else
    line="not installed"
  fi
  printf '  %-22s %s\n' "Thunderbird" "$line"
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
    OBSIDIAN=1 FIREFOX=1 FFTHEME=0 ZED=1 LAZYGIT=1 NVIM=1 GTK=1 SOURCE=1 TBIRD=1 CURSOR=1 PROFILES=()
    while [ $# -gt 0 ]; do
      case $1 in
        --no-obsidian) OBSIDIAN=0 ;;
        --no-firefox) FIREFOX=0 ;;
        --no-zed) ZED=0 ;;
        --no-lazygit) LAZYGIT=0 ;;
        --no-nvim) NVIM=0 ;;
        --no-gtk) GTK=0 ;;
        --no-gtksourceview) SOURCE=0 ;;
        --no-thunderbird) TBIRD=0 ;;
        --no-cursor) CURSOR=0 ;;
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
    [ "$ZED" = 1 ] && zed_install
    [ "$LAZYGIT" = 1 ] && lazygit_install
    [ "$NVIM" = 1 ] && nvim_install
    [ "$GTK" = 1 ] && gtk_install
    [ "$SOURCE" = 1 ] && gtksourceview_install
    [ "$TBIRD" = 1 ] && thunderbird_chrome_install
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
    zed_unselect
    [ "$LOOK" = 1 ] || zed_uninstall
    lazygit_uninstall
    nvim_uninstall
    gtk_uninstall
    gtksourceview_uninstall
    thunderbird_chrome_uninstall
    exit 0 ;;
  status) status ;;
  -h|--help|help) usage ;;
  *) echo "apps.sh: unknown command $cmd" >&2; usage >&2; exit 2 ;;
esac
