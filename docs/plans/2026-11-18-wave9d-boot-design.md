# Wave 9d: boot in Crate's look (rEFInd and Plymouth) — design

Date: 2026-11-18. Status: approved in conversation, pending review of this document. Revised the same
day: a first version themed GRUB itself (kept in git history); Diego chose rEFInd for a richer screen.
The last part of Wave 9; crate-for-ryoku 0.8.0 follows once it is done.

## Goal

From power-on to the lock screen the machine reads as Crate: a rEFInd menu that looks like Ryoku's
reload cover under Crate (the cover mark, a tracked caps line, a beam) with the installed systems below
it as Crate-coloured logos; then the Crate Plymouth splash; then the Crate lock screens on SDDM.

Success: `sudo crate-for-ryoku boot apply` installs and themes rEFInd, puts it first, hides GRUB's menu
and sets the splash; a reboot shows them; `sudo crate-for-ryoku boot revert` puts the firmware boot
order, GRUB's menu and the Ryoku splash back; nothing on the way can stop the machine from booting.

## Found (2026-11-18)

- Boot: GRUB (`\EFI\cachyos\grubx64.efi`, BootOrder `0007,0005,...`, 0005 Windows Boot Manager), ESP
  mounted at `/boot/efi`, `/etc/default/grub` `GRUB_TIMEOUT='5'`, `GRUB_TIMEOUT_STYLE=menu`. GRUB carries
  the btrfs snapshot entries ("CachyOS Linux snapshots").
- mkinitcpio `HOOKS` include `plymouth`; Plymouth theme `ryoku`; the disk is not encrypted.
- `refind` 0.14.2 is in the repos (not installed). `refind-install` copies rEFInd to
  `<ESP>/EFI/refind/` and puts its own NVRAM entry first.
- Ryoku's reload cover under Crate: canvas, `theme/crate/cover-mark.svg` with a cyan glow, a tracked caps
  label with its kanji gloss (`SHELL RELOADING 再読込`), an indeterminate 160 px beam.
- A QEMU/OVMF spike rendered the composition: banner with mark, label and beam, logos below on a raised
  6 px selection. Found there: rEFInd draws text from its font PNG and colours it for the background
  (black glyphs, inverted on a dark banner); in the spike it appended its default tools (about, exit,
  reboot, firmware) to the configured `showtools` list, the striped tile being `about` without an icon.

## Decisions (Diego, 2026-11-18)

- rEFInd starts CachyOS by chainloading the existing GRUB, whose menu becomes hidden with a one-second timeout (with zero GRUB checks for a key only once):
  rEFInd needs no kernel, initramfs or btrfs setup, the snapshots stay one Esc away in GRUB, and GRUB stays
  in the firmware boot menu as the fallback.
- The systems show as their own marks in Crate's colours (the crate-icons rule for brand apps): CachyOS
  from `icons/brand-icons.json` `simple-icons/cachyos`, Windows as the four squares.
- The beam is static (rEFInd has no animation).
- Plymouth: pure black, the Crate mark, a hairline beam filling in cyan with the boot progress (unchanged
  from the first version).

## Components

### `boot/refind/crate/` and its build (`package/build-boot.sh`)

- `theme.conf` (included by refind.conf): `banner themes/crate/banner.png`, `banner_scale fillscreen`,
  `selection_big`, `selection_small`, `font themes/crate/font.png`, `icons_dir themes/crate/icons`,
  no `big_icon_size`/`small_icon_size` (rEFInd doubles icons on screens wider than 1920 only while they
  are unset; icons are drawn at 256/96 and selection tiles at 288/128), `hideui hints,arrows,badges,label` (no label text and no
  countdown line), no `showtools` (rEFInd appends its defaults to any list, so its default row stays and
  every default tool, `func_*` and scanned `tool_*`, gets a Crate line icon), `use_graphics_for windows,grub`.
- Rendered at build: `banner.png` at 3840x2400 (canvas, the cover mark with its glow in the upper third,
  `SELECT A SYSTEM` tracked caps in the secondary tone with `起動` in the faint tone, a static beam: hairline
  track and a cyan glint); `icons/os_cachyos.png`, `icons/os_win.png` (secondary tone, sized so the Crate
  mark stays first; CachyOS's bubbles in cyan, Windows's bottom-right square a cyan outline); tool icons in Solar line style; `selection_big.png`/`selection_small.png` (raised
  `#0f1016`, 6 px corners, hairline, a cyan pick-edge at the bottom); `font.png` (JetBrains Mono, black
  glyphs, uppercase drawn for lowercase, tracked cells).

### `boot/plymouth/crate/` — as in the first version.

### `package/boot.sh` (`crate-for-ryoku boot apply|revert|status`)

- `apply` (root): needs `refind-install` (the `refind` package) and the ESP at `/boot/efi`. Records once in
  `/var/lib/crate-for-ryoku/boot.env`: the BootOrder (`efibootmgr`), the Plymouth theme, the
  `GRUB_TIMEOUT` and `GRUB_TIMEOUT_STYLE` lines; backs up `/etc/default/grub`, `grub.cfg` and any existing
  `<ESP>/EFI/refind/refind.conf`. Runs `refind-install` when rEFInd is not on the ESP; copies the theme to
  `<ESP>/EFI/refind/themes/crate`; writes `refind.conf` (`include themes/crate/theme.conf`, `scanfor
  manual`, a `CachyOS` stanza loading `\EFI\cachyos\grubx64.efi` and, when present, a `Windows` stanza
  loading `\EFI\Microsoft\Boot\bootmgfw.efi`); sets `GRUB_TIMEOUT=1` and `GRUB_TIMEOUT_STYLE=hidden` and
  runs `grub-mkconfig`; runs `plymouth-set-default-theme -R crate`. Every command is printed first; a
  failing step stops with how to finish or revert.
- `revert` (root): `efibootmgr -o <recorded order>`, the GRUB lines back and `grub-mkconfig`, the recorded
  Plymouth theme with `-R`, the previous `refind.conf` back (rEFInd's files stay on the ESP, no longer
  first).
- `status`: BootOrder head, whether rEFInd is first and themed, GRUB timeout style, Plymouth theme.
- `CRATE_SYSTEM_ROOT` prefixes `/etc`, `/boot`, `/var/lib` for tests and skips the root check.

### Packaging

The PKGBUILD installs the themes under `/usr/share/crate-for-ryoku/boot` (the Plymouth theme also in
`/usr/share/plymouth/themes/crate`); `refind` becomes an optdepend ("for crate-for-ryoku boot"); `grub`
leaves makedepends. `crate-for-ryoku uninstall` reminds of `boot revert` while `boot.env` exists.

## If a boot goes wrong

- rEFInd does not show: the firmware boot menu (F12 on most laptops) still lists CachyOS (GRUB) and
  Windows; boot one and run `sudo crate-for-ryoku boot revert`.
- GRUB's menu (snapshots, the LTS kernel): tap Esc or hold Shift right after choosing CachyOS in rEFInd.
- A blank splash: the boot continues to the lock screen; for a boot without it, open GRUB's menu with Esc,
  press `e` and add `plymouth.enable=0`.

## Testing

- pytest: the rEFInd theme files exist in the build with the conf keys and colours expected, `font.png`
  has 96 cells of black glyphs, the logos come from the brand set; the Plymouth checks as before.
- `boot.sh` against a fake root with stub `refind-install`, `efibootmgr`, `grub-mkconfig`,
  `plymouth-set-default-theme`: apply writes refind.conf with the stanzas, the theme and the GRUB lines and
  records the BootOrder; revert restores the order, the lines byte for byte and the splash; apply twice
  keeps the first record; no Windows loader → no Windows stanza; missing `refind-install` → a clear stop.
- QEMU/OVMF at 1920x1200 with a fake ESP (the real refind.conf the script writes), reviewed with Diego
  before `apply` on his machine.
