#!/usr/bin/env bash
# crate-for-ryoku boot: the Crate GRUB menu and Plymouth splash, on and off.
#
#   sudo crate-for-ryoku boot apply    record what you have, then turn Crate's on
#   sudo crate-for-ryoku boot revert   put the recorded GRUB theme and splash back
#   crate-for-ryoku boot status        what the boot uses now (no root needed)
#
# apply copies the themes to /usr/share when the package has not, keeps
# /etc/default/grub as /var/lib/crate-for-ryoku/grub.default.before-crate, sets
# GRUB_THEME and runs grub-mkconfig, then `plymouth-set-default-theme -R crate`,
# which rebuilds the initramfs. Every command is printed before it runs.
#
# If a boot goes wrong: a text GRUB menu means the theme did not load (boot as
# usual, then revert); for a boot without the splash press e on the GRUB entry
# and add plymouth.enable=0 to the linux line.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
R=${CRATE_SYSTEM_ROOT:-}
THEMES=${CRATE_BOOT_THEMES:-$HERE/boot}
GRUB_DEFAULT=$R/etc/default/grub
GRUB_CFG=$R/boot/grub/grub.cfg
STATE=$R/var/lib/crate-for-ryoku
CRATE_THEME_TXT=/usr/share/grub/themes/crate/theme.txt
CRATE_LINE="GRUB_THEME='$CRATE_THEME_TXT'"

say()  { printf '\033[36m::\033[0m %s\n' "$*"; }
die()  { printf '\033[31m!!\033[0m %s\n' "$*" >&2; exit 1; }
run()  { say "running: $*"; "$@"; }
# run_quiet: say the command, keep its own chatter out of the way
run_quiet() { say "running: $*"; "$@" >/dev/null; }

need_root() {
  [ -n "$R" ] || [ "$(id -u)" = 0 ] || die "this changes the boot: run it with sudo (sudo crate-for-ryoku boot $1)"
}

current_plymouth() {
  plymouth-set-default-theme 2>/dev/null || sed -n 's/^Theme=//p' "$R/etc/plymouth/plymouthd.conf" 2>/dev/null || true
}
current_grub_line() { grep -m1 -E '^GRUB_THEME=' "$GRUB_DEFAULT" 2>/dev/null || true; }

# set_grub_line LINE: the first GRUB_THEME= line becomes LINE (added when there
# is none); an empty LINE removes it. Every other byte of the file stays.
set_grub_line() {
  python3 - "$GRUB_DEFAULT" "$1" <<'PY'
import os, sys
path, line = sys.argv[1], sys.argv[2]
text = open(path).read()
lines = text.split("\n")
idx = next((i for i, l in enumerate(lines) if l.startswith("GRUB_THEME=")), None)
if idx is not None and line:
    lines[idx] = line
elif idx is not None:
    del lines[idx]
elif line:
    if lines and lines[-1] == "":
        lines.insert(len(lines) - 1, line)
    else:
        lines.append(line)
tmp = path + ".crate-tmp"
with open(tmp, "w") as f:
    f.write("\n".join(lines))
os.chmod(tmp, os.stat(path).st_mode & 0o7777)
os.replace(tmp, path)
PY
}

ensure_themes() {
  local kind dest
  for kind in plymouth grub; do
    dest=$R/usr/share/$kind/themes/crate
    if [ ! -d "$dest" ]; then
      [ -d "$THEMES/$kind/crate" ] || die "no $kind theme in $THEMES/$kind/crate (install the crate-for-ryoku package)"
      mkdir -p "$(dirname "$dest")"
      cp -a "$THEMES/$kind/crate" "$dest"
      say "copied the $kind theme to $dest"
    fi
  done
}

apply() {
  need_root apply
  [ -f "$GRUB_DEFAULT" ] || die "no $GRUB_DEFAULT: this boot is not GRUB's"
  [ -f "$GRUB_CFG" ] || die "no $GRUB_CFG to regenerate"
  ensure_themes
  mkdir -p "$STATE"
  if [ ! -f "$STATE/boot.env" ]; then
    cp -p "$GRUB_DEFAULT" "$STATE/grub.default.before-crate"
    cp -p "$GRUB_CFG" "$STATE/grub.cfg.before-crate"
    { printf 'PREV_PLYMOUTH=%s\n' "$(current_plymouth)"; printf 'PREV_GRUB_THEME=%s\n' "$(current_grub_line)"; } > "$STATE/boot.env"
    say "recorded your boot in $STATE/boot.env"
  fi
  set_grub_line "$CRATE_LINE"
  say "GRUB_THEME set in /etc/default/grub"
  run_quiet grub-mkconfig -o "$GRUB_CFG" \
    || die "grub-mkconfig failed: GRUB_THEME is already Crate's in /etc/default/grub; run grub-mkconfig -o /boot/grub/grub.cfg by hand, or sudo crate-for-ryoku boot revert"
  run plymouth-set-default-theme -R crate \
    || die "plymouth-set-default-theme failed (the GRUB menu is already Crate's); fix the initramfs build, or sudo crate-for-ryoku boot revert"
  say "Crate's boot is on: reboot to see the GRUB menu and the splash"
}

revert() {
  need_root revert
  [ -f "$STATE/boot.env" ] || die "nothing to revert: crate-for-ryoku boot apply was never run"
  local prev_ply prev_line
  prev_ply=$(sed -n 's/^PREV_PLYMOUTH=//p' "$STATE/boot.env")
  prev_line=$(sed -n 's/^PREV_GRUB_THEME=//p' "$STATE/boot.env")
  set_grub_line "$prev_line"
  say "GRUB_THEME put back in /etc/default/grub"
  run_quiet grub-mkconfig -o "$GRUB_CFG" || die "grub-mkconfig failed; run grub-mkconfig -o /boot/grub/grub.cfg by hand"
  if [ -n "$prev_ply" ]; then
    run plymouth-set-default-theme -R "$prev_ply" || die "plymouth-set-default-theme -R $prev_ply failed; run it by hand"
  fi
  rm -f -- "$STATE/boot.env"
  say "your boot is back (the first backup stays at $STATE/grub.default.before-crate)"
}

status() {
  local ply line
  ply=$(current_plymouth)
  line=$(current_grub_line)
  printf '  %-12s %s\n' "Plymouth" "${ply:-unknown}$([ "$ply" = crate ] && echo ' (Crate)')"
  if [ "$line" = "$CRATE_LINE" ]; then
    printf '  %-12s %s\n' "GRUB" "Crate ($CRATE_THEME_TXT)"
  else
    line=${line#GRUB_THEME=}; line=${line//\'/}; line=${line//\"/}
    printf '  %-12s %s\n' "GRUB" "${line:-no theme}"
  fi
}

case ${1:-status} in
  apply) apply ;;
  revert) revert ;;
  status) status ;;
  -h|--help|help) sed -n '2,15p' "$0" ;;
  *) echo "crate-for-ryoku boot: unknown command $1 (apply, revert, status)" >&2; exit 2 ;;
esac
