# Wave 9d: boot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, as for Wave 9). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Crate GRUB and Plymouth themes, shipped as files and turned on by `sudo crate-for-ryoku boot apply`.

**Architecture:** theme sources under `boot/`, rendered assets from `package/build-boot.sh` (called by `package/build.sh`), a root-only `package/boot.sh` behind `crate-for-ryoku boot`, and the PKGBUILD laying the themes in `/usr/share`.

**Tech Stack:** Plymouth script, GRUB theme format, bash, Python (PIL for images), pytest, QEMU/OVMF for the preview.

**Spec:** `docs/plans/2026-11-18-wave9d-boot-design.md`

> Revised 2026-11-18: the GRUB theme (Task 2, the GRUB parts of Tasks 3-5) was replaced by a rEFInd
> theme that chainloads a hidden GRUB, as the revised spec describes; the GRUB tasks below are history.

## Global Constraints

- Colours: black `#000000` (Plymouth background only), and tokens: `#06b6d4`, `#999ca0`, `#212226`, `#f1f5f9`, hairline `rgba(241,245,249,0.1)`.
- Theme names: Plymouth `crate`, GRUB `/usr/share/grub/themes/crate/theme.txt`.
- State: `/var/lib/crate-for-ryoku/boot.env` (`PREV_PLYMOUTH=`, `PREV_GRUB_THEME=` the full original line or empty), backup `grub.default.before-crate`.
- `CRATE_SYSTEM_ROOT` prefixes `/etc`, `/boot`, `/usr/share`, `/var/lib` in `boot.sh`; under it the root check is skipped.
- Nothing in `crate-for-ryoku install` touches the boot.

## Review Focus

- `/etc/default/grub` with `GRUB_THEME` commented out, quoted with " or ', or absent: apply and revert restore the file byte for byte.
- A second `apply` after a revert, and an `apply` twice: the record always holds the pre-Crate values.
- `plymouth-set-default-theme -R` failing (e.g. mkinitcpio error): the command stops, GRUB already changed is reported, and `revert` still works.
- A release-folder install without the package: `apply` copies the themes from the folder.
- `status` run as a normal user: no root needed, no writes.

---

### Task 1: Plymouth theme and its assets

**Files:** Create `boot/plymouth/crate/crate.plymouth`, `boot/plymouth/crate/crate.script`, `package/build-boot.sh` (renders `mark.png` with `rsvg-convert`, the beam and prompt PNGs with Python/PIL into `$OUT/boot/plymouth/crate`); Modify `package/build.sh` (call it); Test `boot/tests/test_boot.py` (`test_plymouth_theme_is_complete`, `test_plymouth_script_registers_its_callbacks_and_crate_colours`).

- [ ] RED (tests build via `package/build-boot.sh OUT`) → write the files → GREEN. Commit `feat(boot): a Crate Plymouth splash`.

### Task 2: GRUB theme and its assets

**Files:** Create `boot/grub/crate/theme.txt`; extend `package/build-boot.sh` (background 1920x1080 from the Groove webp, two pf2 sizes with `grub-mkfont`, `select_w.png`, `select_c.png`); Test `test_grub_theme_parses_and_its_files_exist`, `test_grub_theme_uses_crate_colours`.

- [ ] RED → write → GREEN. Commit `feat(boot): a Crate GRUB menu`.

### Task 3: `boot.sh` and `crate-for-ryoku boot`

**Files:** Create `package/boot.sh`; Modify `bin/crate-for-ryoku` (dispatch `boot`, usage), `package/uninstall.sh` (the revert hint), `package/build.sh` (copy and `bash -n` it); Tests in `boot/tests/test_boot.py` with a fake root and stub commands: apply/revert/status cases from the spec, the Review Focus inputs, a failing `grub-mkconfig`.

- [ ] RED → implement → GREEN. Commit `feat(boot): crate-for-ryoku boot apply, revert and status`.

### Task 4: packaging, CI and docs

**Files:** `packaging/aur/crate-for-ryoku/PKGBUILD` (install both themes), `boot/tests/package-boot.sh` (the PKGBUILD lays them), `.github/workflows/*.yml` (run `boot/tests`), README and `docs/boot.md` (apply, revert, what to do if a boot goes wrong).

- [ ] RED → GREEN with the full suites. Commit `feat(packaging): ship the boot themes, and their docs`.

### Task 5: preview and live

- [ ] Build a standalone GRUB EFI image with the theme and a fake menu (`grub-mkstandalone`), boot it in QEMU with OVMF, `screendump` it, review with Diego.
- [ ] Build the package, Diego installs it and runs `sudo crate-for-ryoku boot apply`, reboots; review the menu and the splash; `boot revert` stays one command away.
