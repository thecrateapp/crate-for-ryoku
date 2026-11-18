# The Crate boot: GRUB menu and Plymouth splash

`crate-for-ryoku` ships two boot themes as files; nothing turns them on until you ask:

- **GRUB** (`/usr/share/grub/themes/crate`): the Groove wallpaper, a small `CRATE` label, the entries
  in JetBrains Mono, the selected one in cyan with a mark at its left, and the countdown as a caps line
  (`BOOT IN 5S`). GRUB will not draw a progress bar thinner than about 24 px, so there is none.
- **Plymouth** (`/usr/share/plymouth/themes/crate`): pure black, like the framebuffer before it and the
  greeter after it, the Crate mark, and a hairline beam whose cyan fill follows the boot. A bullet
  prompt is there for encrypted disks.

## Turning it on and off

```bash
sudo crate-for-ryoku boot apply    # records your GRUB theme and splash, then sets Crate's
crate-for-ryoku boot status        # what the boot uses now
sudo crate-for-ryoku boot revert   # puts the recorded ones back
```

`apply` keeps `/etc/default/grub` as `/var/lib/crate-for-ryoku/grub.default.before-crate`, sets
`GRUB_THEME`, runs `grub-mkconfig -o /boot/grub/grub.cfg`, then `plymouth-set-default-theme -R crate`
(which rebuilds the initramfs). It prints each command before running it, and stops with a message
saying how to finish by hand if one fails. `crate-for-ryoku uninstall` reminds you to revert when the
boot is still Crate's.

## If a boot goes wrong

- **A text GRUB menu**: the theme did not load. Boot as usual and run `sudo crate-for-ryoku boot revert`.
- **A blank or text splash**: press Esc to see the boot log. For a boot without the splash, press `e` on
  the GRUB entry, add `plymouth.enable=0` to the `linux` line and press Ctrl+X.
- The untouched `/etc/default/grub` is at `/var/lib/crate-for-ryoku/grub.default.before-crate`.

Neither theme can stop a machine from booting: GRUB falls back to its text menu and Plymouth to text.
