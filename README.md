# Crate for Ryoku

Crate's look, and Crate itself, on a [Ryoku](https://github.com/Ryoku-dev/ryoku)
desktop. One install gives you:

- **The Crate rice**: Crate's palette and type across the shell, the Hub and
  the apps (cyan marks, JetBrains Mono caps navigation, hairlines, Bricolage
  titles), the Groove and Sheen wallpapers, and the Crate fastfetch emblem.
- **crate-mark**: the Crate logo on the QS Bar, shown while Crate is installed,
  with now playing, transport and Crate's equalizer (Smart, Genre, Adaptive,
  presets) in a panel drawn to Crate's player spec.
- **Icons**: `crate-icons`, Solar glyphs drawn like Crate's UI; brand apps
  (Firefox, Slack, Steam, JetBrains IDEs...) keep their mark, redrawn in Crate's
  colours; every other installed app gets a Solar glyph (`crateize.py`, kept
  current as you install apps).
- **The terminal**: kitty and alacritty in Crate's ANSI palette, eza in a
  monochrome Crate theme, and the prompt in Crate colours.
- **Crate Palette**: a command palette for Super+Space (`launcher/crate-palette`)
  that searches apps, files, recent files and the Crate library in one field,
  with `cr <query>` for Crate alone; pick it in Hub > App Launcher once it is
  installed from Ryostore (App launchers).
- **The Crate app integration**: the launcher's `cr <query>` search-and-play
  provider (with the Crate desktop app, `crate-desktop-bin`).

## Install

Ryostore (when published): **Crate for Ryoku** in Bundles installs the app, the
package and the plugin, then sets it up for you.

From the AUR:

```sh
paru -S crate-for-ryoku crate-desktop-bin
crate-for-ryoku install
```

From a release folder (`crate-for-ryoku-<version>.tar.gz`):

```sh
./install.sh            # or bin/crate-for-ryoku install
```

`crate-for-ryoku status` shows each piece; `crate-for-ryoku uninstall` goes back
to the icon theme and rice you had. In the GUI: Ryoku Settings > Appearance >
Rices, and QS Bar Settings > Community > Crate.

## What needs Ryoku itself

Most of Crate for Ryoku works on any Ryoku 1.0.7+. A few pieces need Ryoku
changes that are on the way upstream (the
[thecrateapp/ryoku](https://github.com/thecrateapp/ryoku) fork, branch
`feat/user-theme-role-overrides`):

| Piece | Without the Ryoku changes |
|---|---|
| theme style (caps navigation, cyan marks and focus, display weight, no selection fill) | the Crate colours, Ryoku's own look |
| the theme's terminal palette | a terminal derived from the UI roles (mostly cyan) |
| Crate-styled QS Bar Settings rail, launcher focus and picks | Ryoku's defaults |

## Repository

```
rice/crate        the rice (rice.json, wallpaper, launcher hero, fastfetch emblem)
theme/crate       the colour scheme (roles, style, terminal) and its fonts
icons/            crate-icons (build_icons.py) and crateize.py with its brand and Solar glyph map (python3 -m pytest icons/tests)
plugin/crate-mark the bar plugin
launcher/         Crate Palette, the Super+Space launcher (node --test launcher/crate-palette/tests/)
shell/            the eza theme and the Pure prompt
wallpaper/        the Groove and Sheen wallpaper generators (render.sh)
package/          build.sh, install.sh, uninstall.sh and the icon watcher units
bin/              the crate-for-ryoku command
packaging/aur/    the crate-for-ryoku PKGBUILD
ryostore/         the Crate for Ryoku bundle and the crate-mark entry, ready for Ryostore
docs/             design notes
```

Build a release with `package/build.sh` (needs python-cairo, numpy, Pillow and
librsvg); it writes `dist/crate-for-ryoku-<version>/` and its tarball.

MIT licensed; see NOTICE for Solar (CC BY 4.0), the fonts (OFL) and the Crate
mark.
