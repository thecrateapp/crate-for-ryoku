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
- **Other apps in Crate's look**, each only where it is installed: the Crate
  theme copied into every Obsidian vault and selected, Crate's `userChrome.css`
  for Firefox (it replaces WhiteSur or whatever you had and gives it back on
  uninstall; `--no-firefox` skips it), the Chrome theme, which the package
  offers to Chrome and Chromium for every user, a Crate theme for Zed (selected
  as its dark theme; `--no-zed` skips it) and Crate colours for lazygit (only
  where you have no `config.yml` of your own; `--no-lazygit` skips it) and
  Crate's sober syntax for Neovim's tokyonight (`--no-nvim` skips it), Crate's
  corners and hairlines for GTK apps through `user.css` (`--no-gtk`), and a Crate
  GtkSourceView scheme selected in GNOME Text Editor (`--no-gtksourceview`).
  Uninstall puts back the theme each vault and Zed had. See [docs/app-themes.md](docs/app-themes.md).

## Install

From Crate's signed pacman repository (the AUR follows once its registration
reopens). Trust the repository key first, checking that it reads
`AD4DFA15F0A84853D4D711850EB2D64FEFAC7445`:

```sh
curl -fsSLO https://ryoku.cratemusic.app/crate-for-ryoku.gpg
gpg --show-keys crate-for-ryoku.gpg
sudo pacman-key --add crate-for-ryoku.gpg
sudo pacman-key --lsign-key AD4DFA15F0A84853D4D711850EB2D64FEFAC7445
```

Add the repository to `/etc/pacman.conf` above the `[ryoku]` block, then install
and set it up. The repository also ships Ryoku itself, built from the
[thecrateapp/ryoku](https://github.com/thecrateapp/ryoku) fork with Crate's
patches, and pacman takes each package from the first repository that has it, so
the same upgrade moves the Ryoku packages to Crate's builds:

```ini
[crate-for-ryoku]
SigLevel = Required
Server = https://github.com/thecrateapp/crate-for-ryoku/releases/download/repo
```

```sh
sudo pacman -Syu crate-for-ryoku crate-desktop-bin
crate-for-ryoku install
```

From a release folder (`crate-for-ryoku-<version>.tar.gz`):

```sh
./install.sh            # or bin/crate-for-ryoku install
```

`crate-for-ryoku status` shows each piece; `crate-for-ryoku uninstall` goes back
to the icon theme and rice you had. To go back to stock Ryoku, delete the
`[crate-for-ryoku]` block and run `sudo pacman -Syuu`: pacman moves the Ryoku
packages down to the versions `[ryoku]` serves. In the GUI: Ryoku Settings > Appearance >
Rices, and QS Bar Settings > Community > Crate.

## What needs Ryoku itself

Most of Crate for Ryoku works on any Ryoku 1.0.7+. A few pieces need Ryoku
changes from the [thecrateapp/ryoku](https://github.com/thecrateapp/ryoku) fork,
which the pacman repository ships; without them (stock Ryoku, or the release
tarball) they fall back as follows:

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
apps/             app themes: ZapFast, Obsidian, Firefox, Chrome, Zed, lazygit, Neovim, GTK and GtkSourceView (build.py; python3 -m pytest apps/tests)
package/          build.sh, install.sh, uninstall.sh, the lock-skin helpers and the icon watcher units
lockscreen/       the Crate lock skins crate/hero and crate/orbit for Ryoku's qylock (lockscreen/preview.sh, lockscreen/tests/run.sh)
bin/              the crate-for-ryoku command
packaging/aur/    the crate-for-ryoku PKGBUILD (it also offers the Chrome theme to every user)
packaging/repo/   the signed pacman repository: publish.sh and the public key
ryostore/         the Crate for Ryoku bundle and the crate-mark entry, ready for Ryostore
docs/             design notes
```

## The pacman repository

`packaging/repo/publish.sh` builds crate-for-ryoku from its PKGBUILD, takes
`crate-desktop-bin` from the latest thecrateapp/crate release (checked against
the asset digest), adds the Ryoku desktop packages, signs every package and the
database, and uploads them to the `repo` release (never marked latest), dropping
assets it no longer lists. Run it again after a crate-for-ryoku tag or a Crate
release; `--local` stops before the upload, `--rebuild` rebuilds a package that
is already built.

The Ryoku packages are every monorepo package of the fork (all editions, so a
niri or Wayfire box keeps its exact version pins), built at one fork commit in a
clean `archlinux:base-devel` container with Arch's generic flags:

```sh
packaging/repo/build-ryoku.sh --ref <fork commit> ~/Code/Ninja/ryoku
git -C ~/Code/Ninja/ryoku tag -a crate-<pkgver> <fork commit> -m "Crate for Ryoku build <pkgver>"
git -C ~/Code/Ninja/ryoku push crate <branch> crate-<pkgver>
packaging/repo/publish.sh --ryoku ~/.cache/crate-for-ryoku/ryoku/<pkgver>
```

They keep upstream's version scheme (epoch 1, `<VERSION>.r<commit count>.g<sha>`)
and say `RELEASE=crate-<pkgver>` in `/etc/ryoku-release`. They are GPL-3 builds,
so `publish.sh` refuses to upload them until the fork carries the tag
`crate-<pkgver>` on the commit they were built from. Two GPL compositor
plugins, hypr-dynamic-cursors and hyprglass, build from their upstream
repositories at the commit Hyprland's pin table names (or upstream HEAD when it
has none); `publish.sh` tags that commit `crate-<pkgver>` on their mirrors,
[thecrateapp/hypr-dynamic-cursors](https://github.com/thecrateapp/hypr-dynamic-cursors)
and [thecrateapp/hyprglass](https://github.com/thecrateapp/hyprglass), and the
release notes link them. The set stays in the
repository until another `--ryoku` replaces it or `--drop-ryoku` removes it.
Rebuild after every upstream Ryoku release once the fork has merged it: while
our versions are older than upstream's, `ryoku update` takes upstream's builds.

Signing happens only on the maintainer's machine with the repository key
(`AD4DFA15F0A84853D4D711850EB2D64FEFAC7445`, ed25519, sign only, expires
2028-11-15; the public half is `packaging/repo/crate-for-ryoku.gpg`). Its
passphrase sits in the desktop secret store (`secret-tool lookup service
crate-for-ryoku-repo purpose gpg-signing`); without it gpg asks. The database and
files lists are uploaded as real files (`crate-for-ryoku.db`, `.files` and their
`.sig`), since release assets cannot be symlinks.

Build a release with `package/build.sh` (needs python-cairo, numpy, Pillow and
librsvg); it writes `dist/crate-for-ryoku-<version>/` and its tarball.

MIT licensed; see NOTICE for Solar (CC BY 4.0), the fonts (OFL) and the Crate
mark.
