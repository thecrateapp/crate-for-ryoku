# Crate for Ryoku

Crate v3's look on a Ryoku desktop: the QS Bar in the Crate palette (near-black
paper, hairline structure, cyan only where something is active), the Crate Groove
wallpaper set, a hairline icon theme and the Crate mark on the bar.

Built for and tested on Ryoku 1.0.7 (Hyprland 0.57.2, Quickshell 0.3.2).

## What is in the box

| Folder | What it is | Where it goes |
| --- | --- | --- |
| `rice/crate/` | the rice (`rice.json` schema 1, wallpaper, launcher hero, preview) | `~/.config/ryoku/rices/crate` |
| `theme/crate/` | the Crate colour scheme (Noctalia format) | `~/.local/share/ryoku/themes/crate` |
| `icons/crate-icons/` | icon theme: folders, places and ~24 system apps drawn with Solar, Crate's icon set; inherits Papirus-Dark | `~/.local/share/icons/crate-icons` |
| `icons/crateize.py`, `systemd/` | grades every other app's own icon into the Crate palette, on your machine, and regrades when apps are installed | `~/.local/share/icons/crate-icons-auto`, `~/.config/systemd/user/crate-icons-auto.*` |
| `plugin/crate-mark/` | QS Bar plugin: the Crate logo after the launcher; its panel (like the bar's volume panel) has now playing, Crate's volume and Crate's equalizer | installed with `ryoku plugin add` |
| `crate-presence.sh` | shows the bar mark only while the Crate app is installed (`ryoku-shell bar show/hide crate-mark`) | `~/.local/share/crate-for-ryoku/`, run by the watcher |
| `wallpapers/` | Groove, Sheen, Horizon, Handoff, Macro at 3840x2160 and 3840x2400, lossless WebP | `~/Pictures/Wallpapers/crate-*.webp` |

## Install

```bash
./install.sh            # everything, then switches to the rice
./install.sh --help     # --no-apply, --no-icons, --no-auto-icons, --no-plugin, --no-wallpapers, --reapply
```

It only uses Ryoku's own commands: `ryoku plugin add`, `ryoku-hub rice apply crate`,
`ryoku-shell theme crate`, `ryoku-hub desktop icon-theme set crate-icons` and
`ryoku-shell reload`. Nothing needs root.

Before switching, it records your current icon theme and rice in
`~/.local/state/crate-for-ryoku/previous.env` and keeps a copy of Ryoku's `.previous`
snapshot there. If Crate is already the active rice it does not apply it again,
so `.previous` keeps pointing at the look you had before Crate.

## Change things from the GUI

- Rice: Ryoku Settings > Appearance > Rices (Super+comma).
- Wallpaper: the wallpaper picker (Super+W). The five Crate frames are in it.
- Icon theme: Ryoku Settings > App icon theme.
- The bar mark: QS Bar Settings > Community > Crate (colour: theme accent,
  Crate gradient or bar ink; optional "crate" label).

## Uninstall

```bash
./uninstall.sh              # restores the previous look, removes theme, icons, rice and plugin
./uninstall.sh --keep-files # only restores the look
./uninstall.sh --purge      # also deletes the crate-*.webp wallpapers
```

## Dependencies

- Ryoku 1.0.7 or newer (ships Quickshell, matugen, Papirus-Dark and Bibata-Modern-Ice).
- `ttf-jetbrains-mono-nerd` (the QS Bar font).
- For the graded app icons: `python-numpy`, `python-pillow`, `librsvg`. Without them `install.sh`
  skips that step and apps keep their Papirus icons.

## Known limits (Ryoku 1.0.7)

- A rice cannot carry an icon theme or a plugin, so `install.sh` installs them
  beside it. The rice does carry the plugin's placement and settings.
- `rice apply` does not resolve a named user theme; `install.sh` runs
  `ryoku-shell theme crate` after it.
- User themes cannot set `inverseSurface`, so Orpheus and Controls draw active
  states in bone white, not cyan. QS Bar uses the accent and is unaffected.
- Ryogami re-encodes new library PNGs as lossy WebP at screen resolution, which
  smears the hairlines; the wallpapers ship as lossless WebP, which it leaves alone.
- After an icon theme change the dock keeps the old icons until the shell
  reloads; `install.sh` runs `ryoku-shell reload`.
- The QS Bar's own widget icons are fixed Nerd Font glyphs; the icon theme changes
  app and folder icons (dock, launcher, file managers), not the bar glyphs.
- Other apps (Firefox, Steam, Slack...) keep their own drawing, recoloured into the Crate palette
  by `crateize.py`. Keep one as it is with `~/.config/crate-for-ryoku/crateize-keep` (one icon name per
  line), then run `~/.local/share/crate-for-ryoku/crateize.py`.
- Apps whose desktop file sets `Icon=` to an absolute path ignore icon themes and stay unchanged.
- A bar plugin cannot remove its own slot, so the mark is hidden from outside with
  `ryoku-shell bar hide crate-mark` while Crate is not installed. That check runs from
  the `crate-icons-auto` watcher, so with `--no-auto-icons` it runs only at install.
- Volume and EQ in the panel need Crate 3.4 or newer (its control socket); older
  versions get now playing and transport only.

## Credits

- Icon glyphs: [Solar Icons Set](https://www.figma.com/community/file/1166831539721848736) by 480 Design,
  licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), taken from `@solar-icons/react`
  (the package Crate's UI uses), recoloured and placed on Crate folders. See
  `icons/crate-icons/CREDITS`.
- Crate logo: Crate (cratemusic.app).
