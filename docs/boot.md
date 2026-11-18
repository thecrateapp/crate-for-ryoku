# The Crate boot: rEFInd screen and Plymouth splash

`crate-for-ryoku` ships two boot themes as files; nothing turns them on until you ask:

- **rEFInd** (`/usr/share/crate-for-ryoku/boot/refind/crate`, copied to the EFI system partition by
  `apply`): the screen reads like Ryoku's reload cover under Crate, with the Crate mark and its glow, a
  tracked `SELECT A SYSTEM 起動` line and a beam. Below it the installed systems show as their own marks
  in Crate's colours (CachyOS with cyan bubbles, Windows with one cyan outlined square), and under them
  rEFInd's tools (reboot, shut down, firmware settings and the rest) in Crate line icons. The selected
  tile is raised with a cyan edge. rEFInd cannot animate, so the beam stands still.
- **Plymouth** (`/usr/share/crate-for-ryoku/boot/plymouth/crate`, copied to
  `/usr/share/plymouth/themes/crate` by `apply`): pure black, like the framebuffer before it and the
  greeter after it, the Crate mark, and a hairline beam whose cyan fill follows the boot. A bullet
  prompt is there for encrypted disks.

rEFInd's CachyOS entry starts the GRUB you already have, with its menu hidden for one second: rEFInd
needs no kernel, initramfs or btrfs setup of its own, and GRUB keeps the snapshot entries one key away.

## Turning it on and off

```bash
sudo pacman -S refind               # once: rEFInd itself
sudo crate-for-ryoku boot apply     # records your boot, then puts Crate's rEFInd first
crate-for-ryoku boot status         # what the boot uses now (no sudo)
sudo crate-for-ryoku boot revert    # puts the recorded boot back
```

`apply` records, once, in `/var/lib/crate-for-ryoku/boot.env`: the firmware boot order
(`efibootmgr`), the Plymouth theme and the `GRUB_TIMEOUT`/`GRUB_TIMEOUT_STYLE` lines; it keeps copies of
`/etc/default/grub`, `/boot/grub/grub.cfg` and any existing rEFInd `refind.conf` there too. Then it:

1. runs `refind-install` when rEFInd is not yet on the ESP or its firmware boot entry is gone (firmware
   updates sometimes drop it), then puts rEFInd's entry first with `efibootmgr -o`;
2. copies the theme to `/boot/efi/EFI/refind/themes/crate` and writes `refind.conf` with a `CachyOS`
   entry (`\EFI\cachyos\grubx64.efi`) and, when Windows is installed, a `Windows` entry;
3. sets `GRUB_TIMEOUT=1` and `GRUB_TIMEOUT_STYLE=hidden` and runs `grub-mkconfig -o /boot/grub/grub.cfg`;
4. copies the splash to `/usr/share/plymouth/themes/crate` and runs `plymouth-set-default-theme -R crate`,
   which rebuilds the initramfs.

Each command is printed before it runs; if one fails, the command stops and says how to finish by hand
or revert. It stops before changing anything when `efibootmgr` shows no boot order. `revert` restores the boot order, the previous `refind.conf`, the GRUB lines (and runs
`grub-mkconfig`) and the splash, and removes Crate's splash folder; rEFInd's files stay on the ESP, no
longer first. `crate-for-ryoku uninstall` reminds you to revert while the boot is still Crate's.

`apply` owns these boot pieces, not the package: removing `crate-for-ryoku` with pacman leaves the
machine booting as it does, and the revert stays at `/var/lib/crate-for-ryoku/boot.sh`
(`sudo bash /var/lib/crate-for-ryoku/boot.sh revert`); pacman prints that line when it removes the package.

## If a boot goes wrong

- **rEFInd does not show**: open the firmware boot menu (F12 on most laptops), which still lists
  CachyOS (GRUB) and Windows Boot Manager; boot one and run `sudo crate-for-ryoku boot revert`.
- **GRUB's menu** (snapshots, another kernel): choose CachyOS in rEFInd, then tap Esc repeatedly or hold
  Shift; GRUB waits one hidden second for it.
- **A blank or text splash**: press Esc to see the boot log. For a boot without the splash, open GRUB's
  menu with Esc, press `e` on the entry, add `plymouth.enable=0` to the `linux` line and press Ctrl+X.
- **Windows asks for its BitLocker recovery key**: with BitLocker or Device Encryption on, Windows can
  notice that a different boot manager started it. Have the recovery key at hand
  (account.microsoft.com/devices/recoverykey) the first time you start Windows from rEFInd; the firmware
  boot menu's Windows Boot Manager entry starts it the usual way.
- The untouched `/etc/default/grub` is at `/var/lib/crate-for-ryoku/grub.default.before-crate`.

Neither theme can stop a machine from booting: GRUB stays in the firmware boot menu, and Plymouth falls
back to text.
