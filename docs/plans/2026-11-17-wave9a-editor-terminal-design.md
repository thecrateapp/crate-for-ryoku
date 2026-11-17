# Wave 9a: editor and terminal in Crate's look — design

Date: 2026-11-17. Status: approved in conversation, pending review of this document.
Wave 9 dresses what Diego uses every day outside Ryoku's shell. It is split by risk into
9a editor and terminal, 9b GTK and Qt apps, 9c more apps and details (Thunderbird, Slack,
cursor, sounds) and 9d boot (GRUB, Plymouth). This spec covers 9a only.

## Goal

The terminal tools and the editor read as Crate, like Obsidian and Firefox already do.

Success: Zed opens in a Crate theme and lazygit draws in Crate colours after
`crate-for-ryoku install`, `crate-for-ryoku uninstall` puts back exactly what was there,
`crate-for-ryoku status` says what is on, and a capture review of Zed, lazygit, btop, yazi and
neovim finds nothing off.

## What is already Crate (found 2026-11-17)

Ryoku's theme daemon renders matugen templates from the active palette, and the Crate theme sets
that palette, so these already follow Crate's colours and are not rebuilt here:

- kitty and alacritty (`current-theme.conf`, `colors.toml`).
- btop: `color_theme = "ryoku"`, the matugen `ryoku.theme`.
- yazi: the daemon's `theme.toml` (cwd `#67e8f9`, hover `#06b6d4` on `#15161d`).
- neovim: Ryoku's LazyVim plugin tints tokyonight from `~/.cache/ryoku/colors.json`, the base16
  set kitty reads.

They get a capture review only; a change is made where a capture shows something off.

Not Crate today:

- Zed 1.28 uses One Dark. matugen renders `~/.config/zed/themes/matugen.json`, but it is not
  selected, and it is a generic Material mapping (solid grey borders, no Crate surface ladder).
- lazygit 0.66 has no theme (green active border, blue selection); its `config.yml` is empty.

## Decisions

- Zed gets a fixed, hand-built "Crate" theme from `apps/tokens.json` (Diego, 2026-11-17), not the
  matugen one. It does not follow the wallpaper, like the rest of the Crate look.
- The Crate terminal palette (`theme/crate/scheme.json` `dark.terminal`) keeps only Crate hues
  (Diego, 2026-11-17, after the live lazygit review): ANSI green, blue and magenta become the two
  cyans (`#06b6d4`, `#67e8f9`), yellow is `warning`, red is `danger` and stays for status (diff
  deletions, errors, unstaged changes); black and white stay the greys. lazygit's diffs, hashes
  and staged files, git in kitty and Zed's terminal all follow it.
- Everything installs, reports and uninstalls through `package/apps.sh`, the same way as the
  Obsidian, Firefox and eza pieces: detected per app, skipped quietly when absent, never over a
  file of the user's own.

## Components

### Zed theme: `apps/zed/crate.json`

One dark theme, Zed theme schema v0.2.0 (`"$schema": "https://zed.dev/schema/themes/v0.2.0.json"`),
family "Crate", theme "Crate", `appearance: dark`. Every value comes from `apps/tokens.json`:

- Surfaces: editor and terminal background `canvas`; panels, sidebars and status bar `object`;
  title bar, tab bar and inactive tabs `raised`; active tab and editor gutter `canvas`; popovers,
  menus and the command palette `popover`; hover and selection fills `secondary`.
- Lines: `border`, `border.variant` and pane dividers `hairline`; `border.focused` and
  `border.selected` `accent`. No solid grey borders.
- Text: `text` primary, `text_secondary` for muted, `text_faint` for placeholders, disabled text
  and line numbers; the active line number `text`.
- Accent: `accent` for focus, the cursor (`players[0]`), links and the active tab indicator;
  editor selection `accent` at low alpha.
- Status: `warning` and `danger` for warnings and errors (and their backgrounds at low alpha);
  `accent` for info and hints; created/modified/deleted git marks `accent_hi`, `warning`, `danger`.
- Syntax, restrained like the monochrome eza theme: most code in text tones (`text` for
  variables, punctuation at `text_secondary`); keywords and functions `accent`; types and strings
  `accent_hi`; numbers and constants `warning`; comments `text_faint` italic. No rainbow.
- Terminal ANSI colours: the same 16 as the Crate kitty theme, so Zed's terminal matches kitty.

### lazygit theme: `apps/lazygit/config.yml`

First line `# crate-for-ryoku: lazygit` (the ownership marker), then only `gui.theme`:
`activeBorderColor` accent + bold, `inactiveBorderColor` the hairline tone,
`searchingActiveBorderColor` warning, `selectedLineBgColor` `raised`,
`inactiveViewSelectedLineBgColor` `secondary`, `optionsTextColor` accent,
`cherryPickedCommitBgColor` secondary with accent text, `unstagedChangesColor` danger,
`defaultFgColor` text. lazygit needs solid hex, so the rgba tokens resolve against `canvas` when
the file is written by hand, and the test checks the resolution.

### Build: `apps/build.py`

Copies `apps/zed/crate.json` and `apps/lazygit/config.yml` into the dist tree next to the other
app themes (`apps/zed/`, `apps/lazygit/`), so the package ships them under
`/usr/share/crate-for-ryoku/apps/`.

### Zed settings editor: `package/zed_settings.py`

Zed's `settings.json` is JSONC (the default file starts with comments). A small module edits it
without reformatting:

- `select(path, theme) -> previous`: tokenizes the file (strings, `//` and `/* */` comments,
  trailing commas), finds the top-level `"theme"` value and replaces only what it must. An object
  gets its `"dark"` value set to `"Crate"`, `mode` and `light` untouched. A string becomes
  `"Crate"`. No `theme` key: one is added before the closing brace. It returns the previous
  value's raw text, or `-` when there was none. A missing file is created with
  `{"theme": {"mode": "system", "light": "One Light", "dark": "Crate"}}`.
- `restore(path, previous)`: puts the recorded raw text back if the current value is still
  "Crate" (the dark slot or the string); a theme picked since is left alone.
- Writes go to a temp file and `os.replace`. Invalid JSONC: no change, a warning, Crate's theme
  file stays installed but unselected.

### `package/apps.sh`

- `zed_present`: `zed` on PATH, `~/.local/zed.app`, or `~/.config/zed/`.
- `zed_install`: copy the theme to `$CFG/zed/themes/crate.json`; run `zed_settings.py select`
  once (like `obsidian_select`, the record in `$REC/zed-settings.list` holds the file and the
  previous value; a second install does not re-select over a theme picked since).
- `zed_uninstall`: `restore` with the record, delete `themes/crate.json` if unchanged since
  install (sha recorded), drop the record.
- `lazygit_install`: write `$CFG/lazygit/config.yml` only if it is absent, empty, or starts with
  the marker; otherwise say "lazygit: you have your own config.yml; left as it is".
- `lazygit_uninstall`: remove the file only if it starts with the marker; leave an empty file
  only if there was one before (recorded).
- `status`: `Zed  installed; Crate theme selected` / `installed; Crate not selected` / `not
  installed`; `lazygit  Crate theme` / `your own config.yml` / `not installed`.
- Flags `--no-zed` and `--no-lazygit`, passed through by `install.sh` like `--no-obsidian`.

## Error handling

Each app is independent: a failure warns and the install carries on (`apps.sh` already reports
"the app themes did not install cleanly" through `install.sh`). Nothing runs as root. Zed picks
changes up live (it watches its themes folder and settings); lazygit reads its config at start.

## Testing

- `apps/tests` (pytest): every colour in `apps/zed/crate.json` and `apps/lazygit/config.yml` is
  a token from `tokens.json` or a token resolved over `canvas`; the Zed file has its required
  keys (`name`, `themes[0].appearance`, `style`); the lazygit file starts with the marker.
- `zed_settings.py`: comments and formatting survive; only `theme.dark` changes; a string theme,
  a missing key and a missing file; `restore` after no change, after the user picked another
  theme, and twice; invalid JSONC is left untouched.
- `apps.sh` install / status / uninstall for Zed and lazygit against a fake HOME (as the
  existing Obsidian and Firefox tests do), including "your own lazygit config" and a second
  install.
- Live: install on Diego's desktop, capture Zed, lazygit, btop, yazi and neovim in kitty, and
  review them with Diego before a release.

## Out of scope

Zed's fonts and UI settings (a theme cannot set them, and they are the user's); neovim, btop and
yazi rebuilds (they follow the palette); the 9b, 9c and 9d sub-waves.
