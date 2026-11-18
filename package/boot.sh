#!/usr/bin/env bash
# crate-for-ryoku boot: the Crate boot screen (rEFInd) and splash (Plymouth), on and off.
#
#   sudo crate-for-ryoku boot apply    record your boot, then put Crate's rEFInd first
#   sudo crate-for-ryoku boot revert   put the recorded boot order, GRUB menu and splash back
#   crate-for-ryoku boot status        what the boot uses now (no root needed)
#
# apply installs rEFInd on the ESP (refind-install, the refind package) and themes it
# like Ryoku's reload cover; its CachyOS entry starts the existing GRUB, whose menu
# becomes hidden (Esc right after choosing CachyOS shows it, snapshots included);
# then `plymouth-set-default-theme -R crate` rebuilds the initramfs. Every command
# is printed before it runs, and the firmware boot menu keeps GRUB as a fallback.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
R=${CRATE_SYSTEM_ROOT:-}
THEMES=${CRATE_BOOT_THEMES:-$HERE/boot}
GRUB_DEFAULT=$R/etc/default/grub
GRUB_CFG=$R/boot/grub/grub.cfg
ESP=$R/boot/efi
RF=$ESP/EFI/refind
STATE=$R/var/lib/crate-for-ryoku
MARK='# crate-for-ryoku: rEFInd'

say() { printf '\033[36m::\033[0m %s\n' "$*"; }
die() { printf '\033[31m!!\033[0m %s\n' "$*" >&2; exit 1; }
run() { say "running: $*"; "$@"; }
run_quiet() { say "running: $*"; "$@" >/dev/null; }

need_root() {
  [ -n "$R" ] || [ "$(id -u)" = 0 ] || die "this changes the boot: run it with sudo (sudo crate-for-ryoku boot $1)"
}

current_plymouth() {
  plymouth-set-default-theme 2>/dev/null || sed -n 's/^Theme=//p' "$R/etc/plymouth/plymouthd.conf" 2>/dev/null || true
}
boot_order() { efibootmgr 2>/dev/null | sed -n 's/^BootOrder: //p'; }
refind_entry() { efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} \{0,1\}rEFInd.*/\1/p' | head -n 1; }
grub_line() { grep -m1 -E "^$1=" "$GRUB_DEFAULT" 2>/dev/null || true; }

# set_grub_line NAME LINE: the first NAME= line becomes LINE (added when there is
# none); an empty LINE removes it. Every other byte of the file stays.
set_grub_line() {
  python3 - "$GRUB_DEFAULT" "$1" "$2" <<'PY'
import os, sys
path, name, line = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path).read().split("\n")
idx = next((i for i, l in enumerate(lines) if l.startswith(name + "=")), None)
if idx is not None and line:
    lines[idx] = line
elif idx is not None:
    del lines[idx]
elif line:
    lines.insert(len(lines) - 1 if lines and lines[-1] == "" else len(lines), line)
tmp = path + ".crate-tmp"
with open(tmp, "w") as f:
    f.write("\n".join(lines))
os.chmod(tmp, os.stat(path).st_mode & 0o7777)
os.replace(tmp, path)
PY
}

write_refind_conf() {
  {
    echo "$MARK"
    echo "# Written by crate-for-ryoku boot apply; boot revert puts the previous one back."
    echo "timeout 5"
    echo "include themes/crate/theme.conf"
    echo "scanfor manual"
    echo
    echo 'menuentry "CachyOS" {'
    echo '    loader \EFI\cachyos\grubx64.efi'
    echo '    icon \EFI\refind\themes\crate\icons\os_cachyos.png'
    echo '}'
    if [ -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi" ]; then
      echo
      echo 'menuentry "Windows" {'
      echo '    loader \EFI\Microsoft\Boot\bootmgfw.efi'
      echo '    icon \EFI\refind\themes\crate\icons\os_win.png'
      echo '}'
    fi
  } > "$RF/refind.conf"
}

install_refind_theme() {
  local dest=$RF/themes/crate
  if [ -d "$dest" ]; then mv -- "$dest" "$dest.old-$$"; fi
  mkdir -p "$RF/themes"
  cp -a "$THEMES/refind/crate" "$dest"
  if [ -d "$dest.old-$$" ]; then rm -r -- "$dest.old-$$"; fi
}

apply() {
  need_root apply
  command -v refind-install >/dev/null || die "rEFInd is not installed: sudo pacman -S refind, then run this again"
  command -v efibootmgr >/dev/null || die "efibootmgr is missing"
  [ -d "$ESP/EFI" ] || die "no EFI system partition at /boot/efi"
  [ -f "$GRUB_DEFAULT" ] && [ -f "$GRUB_CFG" ] || die "no GRUB at /etc/default/grub and /boot/grub/grub.cfg"
  [ -f "$ESP/EFI/cachyos/grubx64.efi" ] || die "no \\EFI\\cachyos\\grubx64.efi on the ESP for rEFInd to start"
  [ -d "$THEMES/refind/crate" ] && [ -d "$THEMES/plymouth/crate" ] || die "no boot themes in $THEMES"
  mkdir -p "$STATE"
  if [ ! -f "$STATE/boot.env" ]; then
    cp -p "$GRUB_DEFAULT" "$STATE/grub.default.before-crate"
    cp -p "$GRUB_CFG" "$STATE/grub.cfg.before-crate"
    if [ -f "$RF/refind.conf" ]; then cp -p "$RF/refind.conf" "$STATE/refind.conf.before-crate"; fi
    {
      printf 'PREV_PLYMOUTH=%s\n' "$(current_plymouth)"
      printf 'PREV_BOOTORDER=%s\n' "$(boot_order)"
      printf 'PREV_GRUB_TIMEOUT=%s\n' "$(grub_line GRUB_TIMEOUT)"
      printf 'PREV_GRUB_TIMEOUT_STYLE=%s\n' "$(grub_line GRUB_TIMEOUT_STYLE)"
    } > "$STATE/boot.env"
    say "recorded your boot in $STATE/boot.env"
  fi
  if [ ! -f "$RF/refind_x64.efi" ]; then
    run refind-install || die "refind-install failed; nothing else was changed (sudo crate-for-ryoku boot revert cleans up)"
    if [ ! -f "$STATE/refind.conf.before-crate" ] && [ -f "$RF/refind.conf" ]; then
      cp -p "$RF/refind.conf" "$STATE/refind.conf.before-crate"
    fi
  else
    local entry rest
    entry=$(refind_entry)
    if [ -n "$entry" ]; then
      rest=$(boot_order | tr ',' '\n' | grep -v -x -i "$entry" | paste -sd, -)
      run efibootmgr -o "$entry${rest:+,$rest}" >/dev/null || die "could not put rEFInd first"
    fi
  fi
  install_refind_theme
  write_refind_conf
  say "rEFInd themed: $RF/themes/crate and refind.conf"
  set_grub_line GRUB_TIMEOUT "GRUB_TIMEOUT=0"
  set_grub_line GRUB_TIMEOUT_STYLE "GRUB_TIMEOUT_STYLE=hidden"
  say "GRUB's menu hidden (Esc right after choosing CachyOS shows it)"
  run_quiet grub-mkconfig -o "$GRUB_CFG" \
    || die "grub-mkconfig failed: /etc/default/grub already hides the menu; run grub-mkconfig -o /boot/grub/grub.cfg by hand, or sudo crate-for-ryoku boot revert"
  if [ ! -d "$R/usr/share/plymouth/themes/crate" ]; then
    mkdir -p "$R/usr/share/plymouth/themes"
    cp -a "$THEMES/plymouth/crate" "$R/usr/share/plymouth/themes/crate"
  fi
  run plymouth-set-default-theme -R crate \
    || die "plymouth-set-default-theme failed (rEFInd and GRUB are already set); fix the initramfs build, or sudo crate-for-ryoku boot revert"
  say "Crate's boot is on: reboot to see it. The firmware boot menu still lists GRUB if you ever need it."
}

revert() {
  need_root revert
  [ -f "$STATE/boot.env" ] || die "nothing to revert: crate-for-ryoku boot apply was never run"
  local ply order tline sline
  ply=$(sed -n 's/^PREV_PLYMOUTH=//p' "$STATE/boot.env")
  order=$(sed -n 's/^PREV_BOOTORDER=//p' "$STATE/boot.env")
  tline=$(sed -n 's/^PREV_GRUB_TIMEOUT=//p' "$STATE/boot.env")
  sline=$(sed -n 's/^PREV_GRUB_TIMEOUT_STYLE=//p' "$STATE/boot.env")
  if [ -n "$order" ]; then
    run efibootmgr -o "$order" >/dev/null || die "could not restore the boot order $order; run efibootmgr -o $order by hand"
  fi
  if [ -f "$STATE/refind.conf.before-crate" ]; then
    cp -p "$STATE/refind.conf.before-crate" "$RF/refind.conf"
  elif [ -f "$RF/refind.conf" ] && [ "$(head -n 1 "$RF/refind.conf")" = "$MARK" ]; then
    rm -f -- "$RF/refind.conf"
  fi
  set_grub_line GRUB_TIMEOUT "$tline"
  set_grub_line GRUB_TIMEOUT_STYLE "$sline"
  run_quiet grub-mkconfig -o "$GRUB_CFG" || die "grub-mkconfig failed; run grub-mkconfig -o /boot/grub/grub.cfg by hand"
  if [ -n "$ply" ]; then
    run plymouth-set-default-theme -R "$ply" || die "plymouth-set-default-theme -R $ply failed; run it by hand"
  fi
  rm -f -- "$STATE/boot.env" "$STATE/refind.conf.before-crate"
  say "your boot is back (rEFInd's files stay on the ESP, no longer first)"
}

status() {
  local ply first entry style
  ply=$(current_plymouth)
  first=$(boot_order | cut -d, -f1)
  entry=$(refind_entry)
  if [ ! -f "$RF/refind_x64.efi" ]; then
    printf '  %-12s %s\n' "rEFInd" "not installed"
  else
    local where="installed, not first" themed=""
    if [ -n "$entry" ] && [ "${first^^}" = "${entry^^}" ]; then where="first"; fi
    if [ -f "$RF/refind.conf" ] && [ "$(head -n 1 "$RF/refind.conf")" = "$MARK" ]; then themed=", Crate theme"; fi
    printf '  %-12s %s\n' "rEFInd" "$where$themed"
  fi
  style=$(grub_line GRUB_TIMEOUT_STYLE); style=${style#*=}
  printf '  %-12s %s\n' "GRUB menu" "${style:-menu}"
  printf '  %-12s %s\n' "Plymouth" "${ply:-unknown}$([ "$ply" = crate ] && echo ' (Crate)')"
}

case ${1:-status} in
  apply) apply ;;
  revert) revert ;;
  status) status ;;
  -h|--help|help) sed -n '2,13p' "$0" ;;
  *) echo "crate-for-ryoku boot: unknown command $1 (apply, revert, status)" >&2; exit 2 ;;
esac
