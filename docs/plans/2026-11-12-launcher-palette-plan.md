# Crate Palette Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, chosen for Phase 1) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Hero launcher look with the agreed D3 command palette, shipped
inside Crate for Ryoku as a Ryostore-style launcher (`crate-palette`) that runs on
stock Ryoku.

**Architecture:** A self-contained store launcher folder (`launcher/crate-palette/`)
honouring the Ryoku launcher contract (`shown`, `show(mon)`, `hide()`, `toggle()`,
`stateDump()`). The ranking, the `cr` prefix, the section merge and the Crate
control-socket protocol live in pure JS libraries (`lib/*.js`) tested with
`node --test`. QML providers feed them: apps from `DesktopEntries`, files from `fd`,
recent files from `recently-used.xbel`, Crate from its JSON-lines control socket
(`$XDG_RUNTIME_DIR/crate/control.sock`) through `Quickshell.Io.Socket`.

**Tech Stack:** QML (Quickshell, Qt 6), JavaScript (`.pragma library`), Node test
runner, Ryoku.Ui `Tokens`, Solar line-duotone icons.

**Spec:** `docs/plans/2026-11-12-polish-plan.md`, "Especificación del launcher (D3)";
mock-up `.superpowers/brainstorm/1284574-1794479984/content/launcher-palette-v2.html`.

## Global Constraints

- Store-launcher rules (`ryostore/launchers/AUTHORING.md`): relative imports stay
  inside the folder; imports limited to QtQuick*, Quickshell*, `shell.services`,
  `Ryoku.Ui(.Singletons)`; apps start through `AppLaunch.run(entry, null)`; windows
  only while shown, `WlrLayer.Overlay`, namespace `"launcher"`, exclusive keyboard
  focus; never write `launcher.json`; no property named after an anchor line; no
  window-manager code. The id `crate-palette` is not a reserved Ryoku id.
- Look: D1 underlined tabs (cyan text + 2 px underline), D2 navigation in
  `Tokens.navFont` caps with `Tokens.trackNav`, cyan section captions
  (`Tokens.caption`), the live row in `Tokens.rowWash` with a 2 px `Tokens.mark`
  bar; colours, type, spacing and motion only from `Tokens`. No emojis.
- Icons: the search glyph and the kind glyphs are Solar line-duotone SVGs from
  `icons/solar-line-duotone.json`, tinted from `Tokens`; never a font glyph.
- Crate images: file paths only, never URLs (they carry the access ticket). Until the
  Crate app writes its art cache (follow-up plan), Crate rows show a Solar kind
  glyph in the round or square art slot.
- Normal search order: APPS, FILES, REC, then CRATE capped at 1 artist, 1 album,
  1 track in that order, with the hint `cr ⇥ for more`. `cr <q>` (or Tab to CRATE)
  shows ARTISTS (round), ALBUMS (4-column grid), TRACKS (small cover + duration).
- Keys: ↑/↓ move, ⇥ cycles ALL → APPS → FILES → CRATE → REC, ↵ opens or plays,
  ⇧↵ opens the item in Crate, Esc closes. ⌥↵ (queue) is shown only once the Crate
  app answers `queue_item` (follow-up plan).
- The footer shows the key hints for the selected kind and the result count.
- Copy in English (the shell translates through `I18n.tr`).

## Review Focus

1. Crate not running: the socket refuses. Expected: the CRATE section shows one row
   "Crate is not running" whose ↵ starts `crate-desktop`; no error spam, apps still work.
2. Fast typing: Crate and fd answers arrive out of order. Expected: a stale answer
   (older request id or query) is dropped, never shown over a newer query.
3. A query that matches nothing anywhere. Expected: an empty state line, footer count 0,
   ↵ does nothing.
4. Closing and reopening: the query, tab and selection reset, the socket reconnects.
5. Light theme or a theme without a style: the palette stays legible because every
   colour comes from `Tokens` (checked in the live run with a built-in theme).

---

### Task 1: Pure query and ranking library

**Files:**
- Create: `launcher/crate-palette/lib/palette.js`
- Test: `launcher/crate-palette/tests/palette.test.mjs`

**Interfaces:**
- Produces: `parseQuery(text) -> {mode: "all"|"crate", text}` (`cr ` prefix, case-insensitive, "cr" alone = crate mode with empty text);
  `rankApps(entries, text, limit) -> entries` (prefix > word-start > substring, then name);
  `merge(sections, mode, tab) -> [{section, rows}]` where `sections` is `{apps, files, recent, crate}`
  and Crate is capped to the first artist, album and track in mode "all";
  `nextTab(tab) -> tab`; `flatten(groups) -> rows` (selection order).

- [ ] **Step 1:** Write tests: `parseQuery("cr rep")` is `{mode:"crate", text:"rep"}`, `parseQuery("Cr")` is crate with `""`, `parseQuery("crow")` is all; `rankApps` puts "Repo Manager" before "Prepare" for "rep"; `merge` in "all" keeps section order APPS, FILES, REC, CRATE and caps Crate to artist→album→track even when Crate returned tracks first; tab "apps" keeps only APPS; `nextTab("rec")` is "all"; an all-empty merge is `[]`.
- [ ] **Step 2:** Run `node --test launcher/crate-palette/tests/` — expected FAIL (module missing).
- [ ] **Step 3:** Implement `lib/palette.js` as a QML `.pragma library` file; the tests load it through `tests/load.mjs`, which strips the pragma and evaluates the file in a `vm` context.
- [ ] **Step 4:** Run the tests — expected PASS.
- [ ] **Step 5:** Commit `feat(launcher): add the palette query, ranking and section merge`.

### Task 2: Crate control-socket protocol library

**Files:**
- Create: `launcher/crate-palette/lib/crate.js`
- Test: `launcher/crate-palette/tests/crate.test.mjs`

**Interfaces:**
- Produces: `searchLine(query, request) -> string` (`{"cmd":"search","query":…,"request":…}\n`);
  `actionLine(cmd, item) -> string` for `play_item`, `show`, `queue_item`;
  `readMessage(line) -> {type, request, items, error} | null`;
  `toRows(items) -> [{kind, title, subtitle, art, ref}]` (kinds artist, album, track; unknown kinds dropped; newlines in titles collapsed; `art` is a path only when it starts with `/`, else `""`);
  `capabilities(hello) -> {queue: bool}` from the hello message's command list when present.

- [ ] **Step 1:** Tests: a search line round-trips through JSON with the request id; `readMessage` ignores non-JSON and returns `null`; `toRows` drops `{kind:"playlist"}`, keeps order, collapses `"Bad\nTitle"`, rejects `art:"https://…"`; `capabilities({})` is `{queue:false}`.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** Run — PASS.
- [ ] **Step 5:** Commit `feat(launcher): speak Crate's control socket from the palette`.

### Task 3: Providers

**Files:**
- Create: `launcher/crate-palette/AppsSource.qml`, `FilesSource.qml`, `RecentSource.qml`, `CrateSource.qml`, `lib/recent.js`
- Test: `launcher/crate-palette/tests/recent.test.mjs`

**Interfaces:**
- Consumes: `palette.js` (`rankApps`), `crate.js` (all).
- Produces: each source has `property string text`, `readonly property var rows`, and `function reset()`.
  `FilesSource` runs `fd` for 3+ characters with a 150 ms debounce under `$HOME`, at most 6 rows `{kind:"file", title, subtitle: dir, path}`.
  `RecentSource` reads `~/.local/share/recently-used.xbel` through `lib/recent.js` `parseXbel(text) -> [{title, path, modified}]` (newest first, `file://` only, decoded).
  `CrateSource` keeps one `Socket`, sends a search per text change with a rising request id, keeps rows only for the latest id, exposes `available` and `canQueue`, and `act(cmd, row)`.

- [ ] **Step 1:** `recent.test.mjs`: two bookmarks, one `https://`, decoded `%20`, newest first.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement `lib/recent.js` and the four sources. **Step 4:** Run — PASS; `qmllint` on the sources clean apart from Quickshell import resolution.
- [ ] **Step 5:** Commit `feat(launcher): feed the palette apps, files, recents and Crate`.

### Task 4: The palette surface

**Files:**
- Create: `launcher/crate-palette/Main.qml`, `Palette.qml`, `ResultRow.qml`, `AlbumTile.qml`, `Glyph.qml`, `assets/icons/*.svg` (magnifer, widget, document, history, user-circle, vinyl, music-note), `tools/export-icons.mjs`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: the launcher contract on `Main.qml`; `stateDump() -> {open, query, mode, tab, selected, count}`.

- [ ] **Step 1:** `tools/export-icons.mjs` writes the seven Solar SVGs from `icons/solar-line-duotone.json` into `assets/icons/`; run it; check each file is a valid SVG.
- [ ] **Step 2:** Build the surface to the spec: centred card (`Tokens.paperLift`, `Tokens.line` edge, ~640 px wide scaled with `Tokens.px`), field row with the Solar magnifier and a 1 px `Tokens.mark` underline, a `CRATE` chip in the field in crate mode, D1 tabs, sections with `Tokens.caption` captions in `Tokens.navFont`, rows with icon or art slot (round for artists), the selected row's wash and 2 px bar, the albums grid in crate mode, the empty state, the footer hints and count. `Glyph.qml` tints an SVG with `MultiEffect` colourization from `Tokens`.
- [ ] **Step 3:** Keys and actions as in Global Constraints; apps through `AppLaunch.run`, files and recents through `Quickshell.execDetached(["xdg-open", path])`, Crate through `CrateSource.act`; close after any launch.
- [ ] **Step 4:** `qmllint` the folder; `node --test` still green.
- [ ] **Step 5:** Commit `feat(launcher): draw the Crate command palette`.

### Task 5: Preview, settings and packaging

**Files:**
- Create: `launcher/crate-palette/Preview.qml` (720 x 250 still of the palette, `QtQuick` + `Ryoku.Ui` only), `settings.json` (`{"capabilities": ["hiddenApps"]}`, honoured by `AppsSource`), `README.md`, `LICENSE` (MIT, the repo's), `assets/preview.webp` (real capture, taken in Task 6)
- Modify: `package/build.sh` (ship `launcher/`), `docs/` (one paragraph on the launcher)

- [ ] **Step 1:** Write the files; `qmllint` Preview.
- [ ] **Step 2:** Commit `feat(launcher): preview, settings and packaging for the palette`.

### Task 6: Live install and verification

- [ ] **Step 1:** Copy the folder into the local ryostore checkout as `launchers/crate-palette`, add its registry entry, run `python3 tools/pack-product.py launchers/crate-palette`, `tests/validate-catalogue.sh` and `python3 tools/security-screen.py --root .`.
- [ ] **Step 2:** With the user's go-ahead: point the store at the local checkout, `ryostore install launchers crate-palette`, pick it in Hub > App Launcher (the user saves).
- [ ] **Step 3:** The user opens Super+Space; captures of: empty, "rep" (apps, files, Crate capped), "cr rep" (artists, album grid, tracks), Crate closed, no results, a built-in theme. Compare with the v2 mock-up and fix drift.
- [ ] **Step 4:** Record the Review Focus outcomes in the ledger; commit the preview capture.

Follow-up plan (Crate app, repo `crate`, branch `feat/linux_desktop_ryoku`): the art
cache at `$XDG_CACHE_HOME/crate/launcher-art/` with file paths in search results, the
`queue_item` command, `show` with an item, and the command list in `hello`.
