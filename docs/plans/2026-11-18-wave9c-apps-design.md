# Wave 9c: the Crate cursor, Thunderbird and Slack — design

Date: 2026-11-18. Status: approved in conversation, pending review of this document.
Part of Wave 9. Sounds are out (Diego, 2026-11-18): a Crate sound theme would need its own audio design.

## Goal

The pointer is Crate's cyan, Thunderbird reads as Crate like Firefox, and the docs say which colours
to pick for Slack's sidebar. All three install, report and uninstall through `crate-for-ryoku`.

## Found (2026-11-17/18)

- Ryoku ships `ryoku-cursor-material-recolor` and the `Bibata-Material-Ryoku` theme: the cursor store
  value `DYNAMIC` ("Follow the wallpaper" in the Hub) recolours Material Bibata to the palette's
  primary, which under the Crate theme is `#06b6d4`. Diego's cursor is `Bibata-Modern-Ice`
  (`~/.config/ryoku/desktop.json` `desktop.cursor.theme`).
- The cursor is set through `ryoku-hub desktop save`, which replaces the whole store: the full
  `ryoku-hub desktop get` document must be saved with only the one key changed. The Hub's own save
  recolours in a goroutine that dies with the CLI process, so the recolour has to be run explicitly.
- Thunderbird 160 reads `userChrome.css` like Firefox (`toolkit.legacyUserProfileCustomizations.stylesheets`).
  Diego's profile `~/.thunderbird/b2ql07ry.default-release` has no `chrome/` and no such pref.
- Slack's sidebar theme is chosen inside Slack only; nothing outside the app sets it.

## Components

### Cursor (`package/apps.sh`, piece "cursor")

- Install (when `ryoku-hub` is present): record the current `desktop.cursor.theme` once; take the full
  `get` document, set `desktop.cursor.theme` to `DYNAMIC`, `save` it; compare a fresh `get` with the
  expected document and warn if any other key changed; run `ryoku-cursor-material-recolor --force --full`
  when present. A later install leaves a cursor picked since.
- Uninstall: while the theme is still `DYNAMIC`, save the full document with the recorded theme back.
- Status `Cursor  Crate cyan (follows the palette)` / `<theme>` / `no Ryoku Hub`. Flag `--no-cursor`.

### Thunderbird

- `apps/thunderbird/chrome/userChrome.css`: Crate's surfaces (canvas, object, raised, popover), hairlines,
  cyan accent and selection, 6 px corners, through Thunderbird 160's CSS variables and the folder pane,
  thread pane, message header and tabs; token values only. Iterated live.
- `apps/build.py` copies it to `<out>/thunderbird/chrome/`.
- `apps.sh`: the Firefox userChrome code becomes `mozilla_chrome_install LABEL SRC RECORD PROFILE...` and
  `mozilla_chrome_uninstall LABEL RECORD` with the same behaviour (the old `chrome/` moved aside to
  `chrome.before-crate` and back, the marked `user.js` pref added and removed, edits kept). Firefox calls
  them with its profiles; Thunderbird with the profiles of `~/.thunderbird/profiles.ini` (same picking:
  each install's default, else the default profile). Status line and `--no-thunderbird`.

### Slack

A section in `docs/app-themes.md`: the Crate colours for Slack's custom sidebar theme (background
canvas, selected item cyan with canvas text, presence `accent_hi`, notification badge `danger`), picked by
hand in Preferences > Themes.

## Testing

- Cursor against a stub `ryoku-hub` (state JSON file: `desktop get` prints it, `desktop save` writes it):
  only `desktop.cursor.theme` changes and `wm` stays byte-equal; uninstall restores; a cursor picked since
  survives; no `ryoku-hub` → skipped; `--no-cursor`; the recolour stub is called.
- Thunderbird: the Firefox install cases (no `chrome/`, an existing folder or symlink, edits, the pref)
  for a Thunderbird profile; every Firefox test still passes after the refactor.
- `userChrome.css` colours are tokens.
- Live: install, capture Thunderbird and the pointer, review with Diego.
