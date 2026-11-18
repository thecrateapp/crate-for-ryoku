# Wave 9d: boot in Crate's look (GRUB and Plymouth) — design

Date: 2026-11-18. Status: approved in conversation, pending review of this document.
The last part of Wave 9; crate-for-ryoku 0.8.0 follows once it is done.

## Goal

From the GRUB menu to the lock screen the machine reads as Crate: a Crate GRUB menu, a Crate
Plymouth splash, then the Crate lock screens that already dress SDDM.

Success: `sudo crate-for-ryoku boot apply` sets both, a reboot shows them, `sudo crate-for-ryoku
boot revert` puts the CachyOS GRUB theme and the Ryoku splash back, and nothing on the way can stop
the machine from booting.

## Found (2026-11-18)

- GRUB (CachyOS EFI entry `\EFI\cachyos\grubx64.efi`, Windows Boot Manager beside it):
  `/etc/default/grub` `GRUB_THEME='/usr/share/grub/themes/cachyos/theme.txt'`, `GRUB_GFXMODE=auto`,
  `GRUB_TIMEOUT='5'`, menu style; the cmdline carries `splash loglevel=3`.
- mkinitcpio `HOOKS` include `plymouth`; `/etc/plymouth/plymouthd.conf` `Theme=ryoku` (a script theme
  owned by `ryoku-desktop`, pure-black background so the framebuffer and the greeter leave no seam).
- The disk is not encrypted: Plymouth asks for no password, so a broken splash can only fall back to
  text, never block the boot. A broken GRUB theme falls back to GRUB's text menu.
- Ryoku never sets the Plymouth theme or `GRUB_THEME` again after install (no code calls
  `plymouth-set-default-theme` or writes `GRUB_THEME`).
- `grub-mkfont` reads the repo's JetBrains Mono woff2; QEMU and OVMF are installed, so the GRUB theme
  can be seen in a VM without touching the real boot.

## Decisions (Diego, 2026-11-18)

- Plymouth: pure black, the Crate mark centred, under it a hairline beam whose fill grows in cyan with
  the boot progress (the kit's Beam).
- GRUB: the Groove wallpaper, the entries in JetBrains Mono caps with tracking, the selected one in
  cyan with a mark at its left, no boxes; the countdown as a hairline.
- The themes ship as files in the `crate-for-ryoku` package; turning them on is a separate, explicit
  root command (`crate-for-ryoku install` runs as the user and never touches the boot).

## Components

### `boot/plymouth/crate/` (script theme `crate`)

- `crate.plymouth` (`ModuleName=script`, `ImageDir`, `ScriptFile`), `crate.script`.
- Images rendered at build: `mark.png` from `brand/crate-logo.svg` (white mark, about 96 px tall at
  1x), `beam-track.png` (1 px tall, `rgba(241,245,249,0.1)`), `beam-fill.png` (2 px tall, `#06b6d4`),
  `bullet.png` and `entry.png` for a password prompt (kept for encrypted installs).
- Script: black background; mark centred slightly above the middle; the track centred under it
  (about 240 px wide); the fill scaled to `progress` from `Plymouth.SetBootProgressFunction` (never
  moving backwards); `SetDisplayPasswordFunction` / `SetDisplayNormalFunction` show and hide a
  bullet prompt; `SetMessageFunction` shows nothing; `SetQuitFunction` hides everything.

### `boot/grub/crate/` (GRUB theme)

- `theme.txt`: `desktop-image: "background.png"`, `desktop-image-scale-method: "crop"`; a
  `boot_menu` in the left third with `item_font`/`selected_item_font` JetBrains Mono, `item_color`
  `#999ca0`, `selected_item_color` `#06b6d4`, `selected_item_pixmap_style "select_*.png"` (a 2 px cyan
  mark on the west edge only), no item boxes; a `progress_bar` `__timeout__` 2 px tall, track
  `#212226`, fill `#06b6d4`; a small caps label above the menu (`CRATE`) in the secondary text tone.
- Build: `background.png` from `build/wallpapers/crate-groove-3840x2160.webp` scaled to 1920x1080;
  `jetbrains-mono-16.pf2` and `-24.pf2` with `grub-mkfont` from `apps/fonts/jetbrains-mono-latin-400-normal.woff2`;
  `select_w.png` (2 x 1 px cyan) and empty `select_c.png`.

### `package/boot.sh` and `crate-for-ryoku boot apply|revert|status`

- `apply` (root): copy the themes to `/usr/share/plymouth/themes/crate` and
  `/usr/share/grub/themes/crate` when they are not there (a release-folder install); record once, in
  `/var/lib/crate-for-ryoku/boot.env`, the current Plymouth theme and `GRUB_THEME` line; keep
  `/etc/default/grub` as `/var/lib/crate-for-ryoku/grub.default.before-crate`; set `GRUB_THEME` to the
  crate theme.txt (replace the line or add it); run `grub-mkconfig -o` on the existing
  `/boot/grub/grub.cfg`; run `plymouth-set-default-theme -R crate` (rebuilds the initramfs).
- `revert` (root): put the recorded `GRUB_THEME` line back (or remove ours when there was none),
  `grub-mkconfig`, `plymouth-set-default-theme -R <recorded>`, drop the record.
- `status` (any user): the Plymouth theme and `GRUB_THEME` in effect, and whether they are Crate's.
- Every step prints what it runs; a failing step stops the command and says how to finish by hand.
  For tests, `CRATE_SYSTEM_ROOT` prefixes every system path and the root check is skipped under it.
- `bin/crate-for-ryoku` dispatches `boot` to it; `crate-for-ryoku uninstall` mentions
  `sudo crate-for-ryoku boot revert` when the boot is Crate's.

### Packaging

The PKGBUILD installs `boot/plymouth/crate` and `boot/grub/crate` from the dist into
`/usr/share/plymouth/themes/crate` and `/usr/share/grub/themes/crate`; nothing runs at install time.

## If a boot goes wrong

- GRUB menu in text: the theme failed to load; boot as usual and run `sudo crate-for-ryoku boot revert`.
- A blank or text splash: press Esc to see the boot log; for a boot without the splash, press `e` on
  the GRUB entry and add `plymouth.enable=0` to the `linux` line.
- `/var/lib/crate-for-ryoku/grub.default.before-crate` is the untouched `/etc/default/grub`.

## Testing

- pytest: the Plymouth theme files and their images exist in the build, the `.plymouth` points at the
  script, the script registers the progress, password, normal and quit callbacks and uses only black,
  the cyan and the hairline; `theme.txt` parses into the expected keys, its colours are tokens, its
  fonts and images exist in the build.
- `boot.sh` against a fake root (`CRATE_SYSTEM_ROOT`) with stub `grub-mkconfig` and
  `plymouth-set-default-theme`: apply sets the line and the theme and records the old ones; a second
  apply keeps the first record; revert restores both lines byte for byte; a missing `GRUB_THEME` line
  is added and removed; status reports both; a failing `grub-mkconfig` stops with a message.
- The GRUB theme in QEMU with OVMF (a standalone GRUB EFI image carrying the theme), captured before
  any real change; then `boot apply` on Diego's machine, a reboot and his review.
