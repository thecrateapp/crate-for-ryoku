# Crate rice for Ryoku: exploration

Status: **applied to the real session** (rice, theme, wallpaper, `crate-icons` and `crate-mark`),
and packaged as `dist/crate-rice-0.3.0` (`package/build.sh`). Captures `0*`, `1[1]`, `2*` and `32`–`34`
come from a nested Hyprland session with an isolated `HOME`; `10`, `30` and `31` come from the real
desktop. The incidents during the exploration, already reverted, are listed at the end.

The Crate desktop app on Ryoku/Hyprland (what to change in `app/listen-desktop`, what the rice can
do alone): [`crate-desktop-on-ryoku.md`](crate-desktop-on-ryoku.md).

## Package (`package/`, built into `dist/`)

```
package/build.sh        assembles dist/crate-rice-<ver>/ + .tar.gz with SHA256SUMS
package/install.sh      theme, icons, wallpapers, rice, plugin; applies through Ryoku's commands
package/uninstall.sh    rice restore previous, icon theme back, removes what it installed
icons/build_icons.py    generates crate-icons (815 files: 16/22/24/32 px + scalable)
icons/solar_export.mjs  vendors Solar glyphs from @solar-icons/react into solar-line-duotone.json
plugin/crate-mark/      QS Bar plugin source (authored in ~/Documents/ryoku-plugins/crate-mark)
```

- `install.sh` records the current icon theme and rice in `~/.local/state/crate-rice/previous.env`
  once, and copies Ryoku's `.previous` slot before any apply. If Crate is already active it does
  not re-apply, so `.previous` keeps the look from before Crate.
- The rice carries the plugin's roster (`look.plugins`) and its placement after the launcher
  (`qsbar.layout`); a rice cannot carry the plugin itself or an icon theme.
- Tested in the sandbox: uninstall → look restored, icon theme back, plugin and folders removed;
  install → rice applied, mark after the launcher, Crate icons in the dock. Run live with Crate
  already active: icons and plugin installed, rice not re-applied.

### crate-icons

Folders, places and 24 generic system apps plus the Crate app with the real logo. The glyphs are
**Solar** (480 Design, CC BY 4.0), the icon family Crate's UI uses through `@solar-icons/react`:
`solar_export.mjs` renders the `line-duotone` weight with `react-dom/server` (same geometry as the
`outline` weight in `@crate/ui`, as strokes, so each size gets its own line weight) and the result is
vendored in `icons/solar-line-duotone.json`, so the build needs no `node_modules`. Of the two duotone
layers, the lighter one (measured by rendering each alone) is the cyan accent; the rest is white ink.
Where Crate's UI already maps a concept, the same Solar icon is used (`vinyl-record`, `settings`,
`pulse`, `camera`, `calendar`, `clock-circle`, `home`, `download`, `share`, `global`, `star`,
`widget`, `trash-bin-trash`). App icons are the bare glyph: the dock and the launcher already draw a
plate behind every icon, so a tile of our own showed a tile in a tile (`build_icons.py --apps tile`
still builds the tiled set). Folders are Crate chrome: raised surfaces and a hairline edge.
Attribution ships in `crate-icons/CREDITS`, `index.theme` and the package README.
Brand apps keep their own icon (inherited from Papirus-Dark). Selected through
`ryoku-hub desktop icon-theme set crate-icons` (the Hub's App icon theme page), which writes GTK 3/4,
qt6ct, kdeglobals and gsettings and is re-applied by `ryoku update`. Running apps (Nautilus) keep the
old icons until they restart.

### crate-icons-auto (crateize)

`icons/crateize.py` covers every app crate-icons does not draw. It runs on the user's machine:
it collects `Icon=` from every installed `.desktop`, resolves each name the way the desktop would
(crate-icons' inheritance chain, then hicolor and pixmaps, the biggest drawing first, since small
sizes are simplified redraws), and writes the app's own icon, recoloured, to `crate-icons-auto`,
which crate-icons inherits from (`crate-icons -> crate-icons-auto -> Papirus-Dark ...`).

The grade, in OKLab: lightness maps onto Crate's ink ramp (lifted off the floor so dark parts
read on the dock plate); the icon's dominant hue, its brand colour, becomes Crate cyan and every
other hue goes neutral, so each icon keeps one accent; when the accent covers most of the icon
(a one-colour logo disc) it drops to the deep end of the Crate logo gradient (#0e7490). It is
baked into plain colours because Quickshell draws icons with Qt's SVG renderer, which has no
filters: SVG sources stay vector with every colour literal rewritten, PNGs and SVGs that embed
bitmaps are graded per pixel.

It is incremental (a manifest keyed on source path, size and mtime: 118 icons in 3 s, a no-op run
in about 1 s) and removes only the files it wrote. `systemd --user` `crate-icons-auto.path` reruns
it when `/usr/share/applications`, `~/.local/share/applications` or the Flatpak exports change; the
shell picks up a new app's graded icon without a reload (checked in the sandbox and live). Opt-outs:
`--keep NAME` or `~/.config/crate-rice/crateize-keep`. The graded icons are generated locally and
never shipped: the drawings belong to their apps. Apps whose `.desktop` points `Icon=` at an absolute
path (Zed, cmux, HP tools here) bypass icon themes and stay as they are.

### crate-mark

The logo's outline path drawn as a QML `Shape` (no image asset), tinted with the theme accent,
Crate's gradient or the bar ink. Its panel offers "Open Crate" (the desktop entry, via
`DesktopEntries`) and "cratemusic.app" (default browser), with Solar `export`, the icon Crate's
UI uses for external links (`ExternalLink` in `@crate/ui`). It writes nothing and runs nothing
until clicked. `ryoku plugin validate`: 0 blocking, 0 warnings.

0.3.0 adds Crate's now playing, read from MPRIS through `Quickshell.Services.Mpris` (allowed for
plugins, so no command and no D-Bus helper). The service picks the player whose bus name is
`org.mpris.MediaPlayer2.crate` (identity "Crate" as a fallback), so another player never shows here.
- Bar: `nowPlaying` = `indicator` (default; three cyan bars while Crate plays), `track` (bars plus
  "artist - title", elided to the bar budget) or `off`. The default stays small because the bar's
  own media widget already names the active player.
- Panel: cover (Crate's cached `file://` art), NOW PLAYING / PAUSED, title, artist · album, a
  hairline progress with times (position read once a second only while the panel is open and
  Crate plays), and previous / play-pause / next with the icons Crate's player uses (Solar
  `skip-previous`/`skip-next` Outline, `play`/`pause` Bold, filled through `SolarFill.qml`).
  "Open Crate" raises the running app over MPRIS, or starts the desktop entry. Seeking is wired
  and turns on when Crate reports `CanSeek` (3.3.1 does not, see `crate-desktop-on-ryoku.md` A4).
- Tested with the real `Panel.qml`, `Widget.qml` and service in a sandbox test window, against a
  stand-in Crate MPRIS player on the sandbox's own D-Bus (`fake_crate_mpris.py`, same bus name and
  capabilities as Crate 3.3.1), so the real player was never touched. Live: installed, no errors
  in the shell log.

## Sources checked

| Source | Version used | Note |
|---|---|---|
| Crate | `origin/main` `859875882` (`v3.3.1-35`), worktree `crate-agents/ryoku-rice`, branch `ui/ryoku_rice` | Website at `app/web`. `app/site` no longer exists (the root `AGENTS.md` is stale there). `/Users/diego/Code/Ninja/musicdock` does not exist on this machine. |
| Visual tokens | `app/web/src/styles/tokens.css`, `app/shared/ui/tokens/themes.css` (generated from `lib/appearance-token-registry.ts`), `interactive.css`, `typography.css` | Live v3 sources, checked by their imports. |
| Ryoku installed | `1.0.7.r5727.gf7197d7`, Hyprland v0.57.2, Quickshell 0.3.2 | |
| Ryoku upstream | `main` = `f7197d72de8a` = tag `v1.0.7` (2026-10-31), identical to the installed version | `unstable-dev` (`473ba1ab`, 1.10.5) is 315 commits ahead. |

## The real Ryoku desktop (1.0.7)

- **Shell:** Quickshell, `ryoku/shell/quickshell/shell/shell.qml`, supervised by the `ryoku-shell daemon` (Go).
- **Compositor:** Hyprland configured in Lua (`ryoku/hyprland/modules/*.lua`). niri is also supported.
- **Bars:** the default is Orpheus; your machine uses **QS Bar** (`barStyle: qsbar`). Sumi, Kairos,
  Shima, Python and Nomarchy also ship.
- **Launcher, notifications, OSD, Controls:** all part of the shell (`modules/launcher`,
  `modules/notifications`, `modules/osd`).
- **Lock screen:** qylock (`clockwork/orbital`), which reads `~/.cache/ryoku/colors.json`.
- **Wallpaper and palette:** Ryogami plus the matugen pipeline in the daemon. A palette is either a
  named theme (`shell.json → themePalette`), the wallpaper palette, or the built-in base.
- **Upstream screenshots** (all pre-Orpheus, so none shows Orpheus):
  - [README hero `blue-hour.webp`](https://github.com/Ryoku-dev/ryoku/blob/f7197d72de8a21e44b0bea922bdd915f28f6b327/docs/media/showroom/blue-hour.webp): top strip, probably QS Bar, 2026-10-12.
  - [`desktop.webp`](https://github.com/Ryoku-dev/ryoku/blob/f7197d72de8a21e44b0bea922bdd915f28f6b327/docs/media/desktop.webp): pill islands, 2026-09-04.
  - [`launcher.webp`](https://github.com/Ryoku-dev/ryoku/blob/f7197d72de8a21e44b0bea922bdd915f28f6b327/docs/media/launcher.webp): 2026-08-21.
  - ryoku.dev/showroom: shots from before 1.0.
- **Own authentic baseline:** `captures/00-baseline-orpheus-noc-rice.png` is Ryoku's stock `noc` rice
  (Orpheus) applied in the sandbox.

## Proposal

The bar is **your QS Bar as it is today**: same layout, widgets, islands, frost, shadow, radius 7,
separators and kanji workspaces. The `qsbar` block is copied verbatim from your `shell.json`. Only
these change:

- **Palette: Crate theme** (`theme/crate/scheme.json`).
  - QS Bar reads `paper = surface #0a0a0f`, `ink = onSurface #f1f5f9`, `sumi = onSurfaceVariant #999ca0`.
  - With your `barColor: accent`, `seal` becomes `primary #06b6d4`. So active fills (accent at 18%)
    and accents are Crate cyan.
- **Wallpaper: "Crate Groove"** (`wallpaper/`).
  - The edge of a record: faint concentric hairlines (fg at .045, track edges at .10) with their
    centre below the bottom-right corner.
  - A single active element: a cyan-hi playhead with glow and beat ticks (the downbeat is heavier).
  - The top band (under the bar) and the left half stay empty to give the eye a rest. No text and
    no grids.
  - Delivered at 3840×2160 and 3840×2400 (your panel), regenerable with `groove.py`.
- **Windows** (`look.hypr.appearance`): 1px border (cyan when active, `#212226` hairline when
  inactive), rounding 6, gaps 10/18, no shadow, no wobble. This replaces your current border 4,
  rounding 8 and gaps 16. It is easy to drop if you only want the bar.
- **Launcher:** Hero variant with a hero rendered from the same groove, a cyan horizon and radius 6.
- **Desktop widgets and visualizer:** off (a clean desktop).
- **Font:** QS Bar already uses JetBrainsMono Nerd Font (Crate's mono for labels and tabular
  numerals). `fontFamily` carries it to the rest of the shell.

### Crate v3 tokens used

| Role | Value | Crate source |
|---|---|---|
| paper / surface | `#0a0a0f` | `--bg`, `themes.css` app surface |
| raised surface | `#15161d` | secondary/accent surface |
| ink | `#f1f5f9` | `--fg` |
| muted | `#999ca0` | text muted |
| faint / outline | `#4a4c52` | text faint |
| hairline | fg at .10 ≈ `#212226` | `--line` |
| accent / active | `#06b6d4` | `--cyan`, primary/ring |
| active highlight | `#67e8f9` | `--cyan-hi` |
| warning | `#fbbf24` | `--amber` |
| danger | `#ef4444` | danger |

`docs/crate-roles-reference.json` holds the full role map, including `inverseSurface` set to cyan,
for when Ryoku allows it (see the findings below).

## Files

```
rice/crate/rice.json      Ryoku rice (schema 1): qsbar verbatim, theme crate, hypr, launcher, widgets off
rice/crate/wall.png       wallpaper 3840x2160 (rice asset)
rice/crate/hero.png       launcher hero
rice/crate/preview.png    preview for the Rices picker
theme/crate/scheme.json   Ryoku user scheme (Noctalia format, dark block) + meta.json + preview.png
wallpaper/groove.py       wallpaper generator (pycairo + numpy + Pillow)
wallpaper/crate-groove-3840x{2160,2400}.png
captures/                 real captures (PNG 3840x2160) + .preview.jpg
docs/orpheus-variant.json Orpheus block from the first iteration (alternative)
```

## Dependencies

- Ryoku 1.0.7 (quickshell 0.3.2, matugen 4.2.0), already installed.
- `ttf-jetbrains-mono-nerd` (JetBrainsMono Nerd Font), already installed. Bricolage Grotesque and
  Roboto are not needed for the bar.
- Bibata-Modern-Ice cursor (shipped with Ryoku).
- Only to regenerate the wallpaper: `python-cairo`, `python-numpy`, `python-pillow`.

## Manual installation (superseded by package/install.sh)

```bash
D=~/Code/Ninja/crate-agents/ryoku-rice/design/ryoku-rice
mkdir -p ~/.local/share/ryoku/themes ~/.config/ryoku/rices
cp -r $D/theme/crate ~/.local/share/ryoku/themes/crate   # Crate theme
cp -r $D/rice/crate  ~/.config/ryoku/rices/crate         # rice
ryoku-hub rice apply crate      # takes a .previous snapshot first
ryoku-shell theme crate         # required: apply does not make the daemon resolve themePalette
```

To undo: `ryoku-hub rice restore previous`. That restores `shell.json`, `desktop.json` (windows),
`theme.json`, `launcher.json`, `widgets.json`, the wallpaper and the rest of the stores
byte-for-byte. In the GUI it is Ryoku Settings › Appearance › Rices.

## What is executed and what is not

- **Executed (real captures with `grim`):**
  - Everything in `captures/0*` and `captures/20*`.
  - Nested Hyprland 0.57.2 with an isolated `HOME`, `XDG_RUNTIME_DIR` and D-Bus, on a 3840×2160
    headless output at scale 1.6667 (your panel's scale).
  - Real Ryoku shell, with the rice installed through `ryoku-hub rice apply` and the theme through
    `ryoku-shell theme`.
  - Real apps: kitty + fastfetch, Firefox on cratemusic.app (the live v3 site), mpv playing a local
    track muted (the bar's MPRIS), Controls and the launcher.
- **Host capture:** `captures/10-bar-before-host-qsbar.png` is your current bar, captured from your
  real desktop. `11-...` is the same bar with the rice, taken from the sandbox.
- **No compositions:** nothing is a montage or AI-generated. The only made images are the wallpaper
  and the launcher hero, which are this rice's assets.

## Still to validate

1. Apply it to the real session (eDP-1 3840×2400 @1.6667) and check the 2400 wallpaper, frost and
   blur over the new wallpaper, and the real dock.
2. GTK/Qt apps, Hub, notifications and **lockscreen** with the Crate theme (they were not captured).
3. Terminal ANSI colours: Ryoku derives them from the roles. In kitty the green slot ends up cyan,
   which needs checking with colourful programs.
4. Dock icons in the sandbox: the magenta ones belonged to apps without a matching desktop entry
   (see findings).
5. Whether you want Crate's window geometry (border 1, gaps 10/18) or to keep yours.

## Findings (Ryoku 1.0.7 and Crate)

1. **`obsidian.css` breaks `rice apply`.** The shipped matugen template uses `.hue/.saturation/.lightness`,
   which matugen 4.2.0 does not resolve. The apply aborts before the palette step. The rice
   switches that template off. (Upstream has later Obsidian/HSL commits.)
2. **User themes cannot set `inverseSurface`.** `usertheme.go` forces `inverseSurface = onSurface`.
   Orpheus and the shell's Controls panel paint active states with that role, so they come out
   bone white, not cyan. A small upstream PR would fix it: optional `mInverseSurface` and
   `mInverseOnSurface` fields. In QS Bar this does not matter, because it uses the accent.
3. **`rice apply` writes `theme.theme` but does not trigger `resolveThemePalette`.** You have to run
   `ryoku-shell theme <id>` afterwards.
4. **Fixed mode with `palette.json` does not reach the shell:** with `followWallpaper:false` and no
   named theme, `Tokens` ignores `colors.json`. It only reaches apps.
5. **`ryoku-shell barstyle` does not validate its argument:** `barstyle --help` saved `"--help"` as
   the bar style.
6. **Crate desktop:** the installed build (`2.4.4-295-g0f92524a`, not v3) opens a window with class
   `crate-desktop`, while its `.desktop` declares `StartupWMClass=app.cratemusic.crate.desktop`.
   Docks do not find its icon. Check this in `app/listen-desktop`.

7. **Icon theme switch needs a shell reload.** After `ryoku-hub desktop icon-theme set`, the dock
   kept the old kitty icon until `ryoku-shell reload`; `ryoku-shell icons` already resolved the new
   path. `install.sh` reloads.
8. **No way to open a bar plugin's panel from outside.** `ryoku-shell plugin <id>` toggles frame
   popouts only; the panel was verified by loading the real `Panel.qml` with PluginKit in a test
   window.
9. **Dock plate plus icon tile.** The dock and the launcher draw their own plate behind each icon,
   so a tiled app icon showed a tile in a tile. App icons are now the bare glyph (default
   `--apps glyph`), which also reads better at 16-24 px.
10. **Qt draws the icons, so no SVG filters.** A recolour has to be baked into the files; an
    feColorMatrix wrapper would render untouched in the dock and launcher.
11. **New apps need no shell reload.** A new `.desktop` resolves its icon fresh, so the
    crate-icons-auto watcher does not reload the shell; only icons that change in place do.

## Incidents during the exploration (already reverted)

- A research subagent ran `ryoku-shell barstyle --help` on the real desktop and left
  `barStyle: "--help"`. It was restored to `qsbar` with `ryoku-shell barstyle qsbar` (verified with
  a capture).
- An `icons` symlink from the sandbox let Ryoku rebuild your `~/.local/share/icons/ryoku-folders`
  overlay with the Crate palette. It was regenerated with `ryoku-cmd-folders` from your real palette
  (`primary #9dcbfc`), and the sandbox no longer links into your `HOME`.
