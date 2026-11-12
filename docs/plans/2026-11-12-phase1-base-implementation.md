# Fase 1 (base) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the roots that keep most Ryoku surfaces out of the Crate style: the Ryoku.Ui kit, a navigation-font token, the shared shell fonts, the palette singletons that ignore a named theme, and fixed display weights.

**Architecture:** Every change hangs off the theme style already in `Tokens` (`shell.json themeStyle`). With no style (Ryoku's own look) every value resolves to exactly what ships today; with Crate's style the kit and the bridged surfaces follow the decisions D1, D2 and D4. The bridged singletons read `Ui.Tokens` whenever Match wallpaper is off, because Tokens already resolves the named theme's palette.

**Tech Stack:** Quickshell QML (Qt 6), Go (`ryoku/shell/ipc`), qmllint, the nested Hyprland sandbox for captures.

**Spec:** `docs/plans/2026-11-12-polish-plan.md` (Fase 0 decisions D1, D2, D4; Fase 1).

**Repo:** `~/Code/Ninja/ryoku`, branch `feat/user-theme-role-overrides` (fork `thecrateapp/ryoku`). Crate theme file: `~/Code/Ninja/crate-for-ryoku/theme/crate/scheme.json`.

## Global Constraints

- No themeStyle means no visual change: every new binding falls back to today's value when the style key is absent.
- D1: tabs = cyan text with a 2 px underline in `Tokens.mark`, no plate; segments and option chips = filled with `Tokens.bone` (cyan under Crate) and `Tokens.inkOnBone` text.
- D2: navigation text (rails, tabs, section captions) uses `Tokens.navFont`, uppercase and tracked when `Tokens.navCaps`; Crate sets `navFont` to `JetBrainsMono Nerd Font`.
- D4: `Btn` gains `outline: bool`; a primary (confirm) button stays filled, an outline (navigation) button is transparent with a `Tokens.mark` edge and text.
- Focus edges use `Tokens.focus`; hover text `Tokens.hoverInk`; captions `Tokens.caption`.
- Japanese only through `UiPreferences`. No emojis. No em-dashes in comments or docs (Ryoku pre-commit hook).
- Commits follow Ryoku: `[ryoku] area: summary` (<= 72 chars); run `.githooks/pre-commit` and `.githooks/commit-msg <file>` by hand before each commit (hooks are not wired in this clone).
- Verification for QML: `/usr/lib/qt6/bin/qmllint --bare <file>` shows no `Error`, plus sandbox captures (`scratchpad/tools/hub-tour`, `sheet2`) with the Crate theme and with a built-in theme.

## Review Focus

1. **Ryoku's own look must not move.** With a built-in theme (no themeStyle), the Hub, the overview and the launcher must render as before: Task 9 captures them under a built-in theme and compares with the pre-change captures.
2. **Match wallpaper on.** The bridged singletons must keep following the wallpaper palette (Scheme), not Tokens, when Match wallpaper is on: Task 6 checks the overview with a wallpaper theme.
3. **Light themes.** The underline, wash and outline must stay legible on a light paper: Task 9 includes one light built-in theme with Crate-like switches set by hand in a test scheme.
4. **Live theme switch.** Switching theme at runtime must restyle without a shell restart (bindings, not one-off reads): Task 9 switches Crate to a built-in theme and back with the Hub open.
5. **Missing font.** A `navFont` naming a family that is not installed must fall back cleanly (Qt substitutes); Task 1's Go test pins the sanitising, Task 9 tries an unknown family in the test scheme.

---

### Task 1: `navFont` style token (daemon, Tokens, docs, Crate theme)

**Files:**
- Modify: `ryoku/shell/ipc/usertheme.go` (themeStyleSpec, themeStyleValues)
- Test: `ryoku/shell/ipc/usertheme_test.go`
- Modify: `ryoku/ui/Singletons/Tokens.qml` (new property and refreshNamed)
- Modify: `docs/store.md` (style list)
- Modify: `~/Code/Ninja/crate-for-ryoku/theme/crate/scheme.json` (`dark.style.navFont`)

**Interfaces:**
- Produces: `Tokens.navFont: string` (the theme's navigation family, default `Tokens.ui`); themeStyle JSON key `navFont` (string, trimmed, at most 128 chars, dropped when empty).

- [ ] **Step 1: Write the failing test** `TestThemeStyleValuesKeepsNavFont` in usertheme_test.go: a spec with `NavFont: "  JetBrainsMono Nerd Font  "` yields `values["navFont"] == "JetBrainsMono Nerd Font"`; `NavFont: "   "` yields no `navFont` key; a 200-char name is dropped.
- [ ] **Step 2: Run** `cd ~/Code/Ninja/ryoku/ryoku/shell/ipc && go test -run TestThemeStyleValuesKeepsNavFont ./...` → FAIL (field missing).
- [ ] **Step 3: Implement** `NavFont string \`json:"navFont"\`` on themeStyleSpec and its sanitising in themeStyleValues (same rules as `Display`).
- [ ] **Step 4: Run** `go test ./...` in shell/ipc → all PASS; `gofmt -l .` empty.
- [ ] **Step 5: Tokens** `property string navFont: ui`; in refreshNamed read `st.navFont` like `st.display` (string, non-empty) and assign `t.navFont = navFontValue || t.ui`. qmllint clean.
- [ ] **Step 6: Docs and theme** Add `navFont` to the style sentence in docs/store.md; add `"navFont": "JetBrainsMono Nerd Font"` to Crate's `dark.style`.
- [ ] **Step 7: Commit** (Ryoku) `[ryoku] shell: let a theme style name the navigation font`; (crate-for-ryoku) `theme: set the navigation font to JetBrains Mono`.

### Task 2: Navigation surfaces use `navFont`

**Files (font.family of the nav label only):**
- Modify: `ryoku/hub/quickshell/Hub.qml` (navLatin), `ryoku/hub/quickshell/pages/KeybindsPage.qml` (category rail), `ryoku/apps/ryovm/quickshell/Rail.qml`, `ryoku/apps/ryostore/quickshell/StoreHeader.qml` (RailItem label), `ryoku/shell/quickshell/shell/modules/bar/barstyles/qsbar/controlcenter/CcRail.qml`, `ryoku/shell/quickshell/keys/Kit.qml` and `keys/CategoryBlock.qml` (rail labels)

**Interfaces:**
- Consumes: `Tokens.navFont` (Task 1).

- [ ] **Step 1:** In each nav label set `font.family: Tokens.navCaps ? Tokens.navFont : Tokens.ui` (navCaps gates it, so a theme that names a font without caps keeps today's rail).
- [ ] **Step 2:** qmllint each file; no `Error`.
- [ ] **Step 3:** Sandbox: copy `ryoku/ui` into `scratchpad/qmlpatch/Ryoku/Ui`, restart the sandbox Hub, `hub-tour profile keybinds`, capture QS Bar Settings and Ryoport; the rails read in JetBrains Mono caps.
- [ ] **Step 4: Commit** `[ryoku] ui: set navigation labels in the theme's navigation font`.

### Task 3: `Tabs` per D1

**Files:**
- Modify: `ryoku/ui/Tabs.qml`

**Interfaces:**
- Consumes: `Tokens.selectFill`, `Tokens.mark`, `Tokens.hoverInk`, `Tokens.navFont`, `Tokens.navCaps`, `Tokens.trackNav`.
- Produces: unchanged public API (`tabs`, `current`, signals).

- [ ] **Step 1:** Plate: when `!Tokens.selectFill` the plate is transparent with no border, and a 2 px bar in `Tokens.mark` sits at the plate's bottom while `on`; with selectFill everything stays as today.
- [ ] **Step 2:** The `//` lead shows only when `on && Tokens.selectFill`. Label: `on` → `Tokens.selectFill ? inkOnBone : Tokens.mark`; hover (not on) → `Tokens.accentMarks ? Tokens.hoverInk : inkDim`; family per Task 2; letterSpacing `Tokens.navCaps ? Tokens.trackNav : Tokens.trackLabel`.
- [ ] **Step 3:** qmllint; sandbox capture of a schema page (GPU) and Game Bar tabs under Crate: underline, no plate.
- [ ] **Step 4: Commit** `[ryoku] ui: underline the live tab when the theme drops the fill`.

### Task 4: Segments, chips, multi and keyboard map (focus, hover)

**Files:**
- Modify: `ryoku/ui/Seg.qml`, `ryoku/ui/Chips.qml`, `ryoku/ui/Multi.qml`, `ryoku/ui/KeyboardMap.qml`

D1 keeps the fill (bone resolves to Crate cyan), so only the edges and hover change.

- [ ] **Step 1:** Any `activeFocus ? Tokens.bone` / `Tokens.ink` edge → `Tokens.focus`; hover text of an unselected item → `Tokens.accentMarks ? Tokens.hoverInk : <today's ink>`.
- [ ] **Step 2:** qmllint; sandbox capture of Controls and Animations pages: filled cyan options, cyan focus.
- [ ] **Step 3: Commit** `[ryoku] ui: give segments and chips the theme's focus and hover`.

### Task 5: Buttons, pickers, rows and small kit pieces (D4)

**Files:**
- Modify: `ryoku/ui/Btn.qml`, `ryoku/ui/Picker.qml`, `ryoku/ui/AppPicker.qml`, `ryoku/ui/SettingRow.qml`, `ryoku/ui/Cell.qml`, `ryoku/ui/Slid.qml`

**Interfaces:**
- Produces: `Btn.outline: bool` (default false). Outline wins over primary when both are set.

- [ ] **Step 1: Btn** `outline` → transparent fill, border `Tokens.mark`, text `Tokens.mark`, hover fill `Tokens.rowWash`; focus edge `Tokens.focus` for every kind; primary unchanged (filled bone, inkOnBone).
- [ ] **Step 2: Picker, AppPicker** hovered row: `Tokens.selectFill ? <today's bone fill> : Tokens.rowWash` with the text in `Tokens.ink` when not filled.
- [ ] **Step 3: SettingRow** focus ring `Tokens.focus`; text selection `selectionColor: Tokens.selectFill ? <today> : Tokens.sun`, `selectedTextColor: Tokens.inkOnBone`.
- [ ] **Step 4: Cell** replace the fixed `rgba(205,196,186,.05)` with `Tokens.tint5`; **Slid** fill and knob in `Tokens.mark`.
- [ ] **Step 5:** qmllint all six; sandbox capture of Global (pickers), Displays (rows) and a dialog with Btn under Crate and under a built-in theme.
- [ ] **Step 6: Commit** `[ryoku] ui: outline buttons and theme-aware pickers, rows and focus`.

### Task 6: Shared shell fonts and the overview bridge

**Files:**
- Modify: `ryoku/shell/quickshell/shell/services/Theme.qml:216-217`
- Modify: `ryoku/shell/quickshell/shell/modules/overview/Singletons/Theme.qml`

**Interfaces:**
- Produces: services `Theme.display: Ui.Tokens.display`, `Theme.displayWeight: Ui.Tokens.displayWeight`, `Theme.mono: Ui.Tokens.mono`.

- [ ] **Step 1: services Theme** `display`, new `displayWeight`, `mono` read Ui.Tokens (Tokens' defaults are today's Fraunces and the mono the rest of the shell uses; check Tokens.mono resolves to JetBrainsMono on this machine before relying on it, otherwise keep the JetBrains literal as the Tokens fallback). Add `font.weight: Theme.displayWeight` where `Theme.display` is used: components/Calendar:115, bar/popouts/MusicPopout:205, MusicHoverPopout:190.
- [ ] **Step 2: overview Theme** when `!Config.matchWallpaper`: `brand` → `Ui.Tokens.sun`, `vermLit` → `Ui.Tokens.sunHi`, `vermDeep` → `Ui.Tokens.sunDeep`; ink ramp `bright/cream` → `Ui.Tokens.ink`, `subtle` → `inkDim`, `dim` → `inkMuted`, `faint` → `inkFaint`; `cardTop` → `paper`, `cardBot` → `Qt.darker(paper, 1.15)`, `tileBg` → `paperLift`; `border` → `line`, `hair` → `lineSoft`, `sheen` → `tint5`; `frameBg`/`threadBg` → `Ui.Tokens.rowWash`; `display` → `Ui.Tokens.display`, `mono` → `Ui.Tokens.mono`. With Match wallpaper on, the existing Scheme expressions stay.
- [ ] **Step 3:** WorkspaceCell:143-149 and DesktopStrip:58-64 selection edge → `Ui.Tokens.mark` when `!Config.matchWallpaper`.
- [ ] **Step 4:** qmllint; sandbox capture of the overview (Super+Tab) under Crate, under a built-in theme (must match the pre-change capture) and with Match wallpaper on (Review Focus 2).
- [ ] **Step 5: Commit** `[ryoku] shell: bridge the overview and shared fonts to the theme`.

### Task 7: Launcher, desktop menu and Kit plugin bridges

**Files:**
- Modify: `ryoku/shell/quickshell/shell/modules/launcher/shared/Singletons/Theme.qml:10-33,82`
- Modify: `ryoku/shell/quickshell/shell/modules/desktop/Singletons/Theme.qml` (brand, display)
- Modify: `ryoku/shell/quickshell/plugins/kit/Singletons/Theme.qml:72` (display only; `sun` and `gold` stay fixed identity marks)

- [ ] **Step 1: launcher Theme** the same bridge as Task 6 for `brand/verm/vermLit/vermDeep`, the ink ramp, `cardTop/tileBg/border`, `threadBg` → `Ui.Tokens.rowWash`, `providerFind` → `Ui.Tokens.sunHi` when not matching, `display` → `Ui.Tokens.display` (the hero rework in Fase 2 builds on this).
- [ ] **Step 2: desktop menu Theme** `brand` → `Ui.Tokens.sun` when not matching; `display` → `Ui.Tokens.display` (import `Ryoku.Ui.Singletons as Ui` if missing).
- [ ] **Step 3: Kit plugins Theme** `display` → `Ui.Tokens.display` (add the import).
- [ ] **Step 4:** qmllint; sandbox capture of the launcher (main variant), the desktop right-click menu and a Kit plugin card under Crate and under a built-in theme.
- [ ] **Step 5: Commit** `[ryoku] shell: bridge the launcher, desktop menu and kit to the theme`.

### Task 8: Display weight on fixed titles

**Files (each `font.family: Tokens.display` with a fixed `Font.Medium`):**
- Modify: `ryoku/hub/quickshell/CompositorControl.qml:85`, `pages/UpdatesPage.qml:717`, `pages/ProfilePage.qml:444`
- Modify: `ryoku/apps/ryostore/quickshell/AppsHero.qml:129`, `ProductCard.qml:79`, `ShowroomStage.qml:265`, `App.qml:610`, `ProductDetail.qml:570`, plus `AppsTile.qml` and `ProductMedia.qml` display texts
- Modify: sidebar `ControlsHero.qml:234`, `cards/SystemWifiPage.qml:251`, `cards/SystemBluetoothPage.qml:298`; welcome `PageTitle.qml:16`, `PageHello.qml:79`, `PageDone.qml:40`, `PageMake.qml:83,145`

- [ ] **Step 1:** Replace the fixed weight with `Tokens.displayWeight` (keep `Font.Medium` only where the text is not a display title).
- [ ] **Step 2:** qmllint all; sandbox capture of Updates, Profile, Ryostore detail and the sidebar hero.
- [ ] **Step 3: Commit** `[ryoku] ui: give the remaining display titles the theme weight`.

### Task 9: Phase verification and live install

**Files:** none new (captures in `scratchpad/phase1/`)

- [ ] **Step 1:** Sandbox, Crate theme: hub-tour every Hub page, QS Bar Settings, overview, launcher, Ryostore, Ryoport; build contact sheets.
- [ ] **Step 2:** Sandbox, a built-in theme: the same tour; compare with pre-change captures (Review Focus 1).
- [ ] **Step 3:** Review Focus 3 to 5: a test scheme with a light paper plus Crate's switches and `navFont: "No Such Font"`; switch themes with the Hub open.
- [ ] **Step 4:** `cd ryoku/shell/ipc && go test ./...` PASS; qmllint over `git diff --name-only --relative` clean.
- [ ] **Step 5:** Show the sheets to the user; on approval build `ryoku-desktop` and `ryoku-shell` packages (pkgrel bump, see memory ryoku-fork) for `sudo pacman -U`, and reinstall Crate for Ryoku for the navFont theme change.
