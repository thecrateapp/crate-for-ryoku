# Crate Design System: Unifying the Ryoku Environment

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native) wave by wave. Waves 0 and 1 are specified to plan granularity; Waves 2 to 6 are task lists that become their own detailed plan once Wave 1 lands and its primitives' APIs are fixed. Steps use checkbox (`- [ ]`) syntax.

**Goal:** One visual language across the whole Ryoku environment, the one the crate-mark panel
already speaks, so drift stops for good. Every surface draws its sliders, chips, icon buttons,
labels, frames and progress from one kit, and a guard stops new bespoke copies.

**Architecture:**
- **One canonical reference:** `plugin/crate-mark/content/Panel.qml`.
- **One kit:** Ryoku.Ui, in the Ryoku fork `~/Code/Ninja/ryoku`, branch `feat/user-theme-role-overrides`. It gains the missing primitives (Beam, Chip, IconButton, Label, Divider, PageHead).
- **One style switch:** `controls: "crate"`. Existing kit components restyle behind it, so every theme without the switch keeps the stock look.
- **The rest of the environment migrates onto the kit**, wave by wave. Today it uses private copies: 8 sliders, 17 progress bars, about 30 chip definitions, 11 or more icon buttons, about 10 caption styles and 26 page headers.
- **A design lint** blocks new copies.

**Spec sources:**
- The four audits of 2026-11-12, summarised below.
- The approved mock-ups: https://claude.ai/artifact/Bhz1QD1jRrM27BLeeDsvpw (version 3; straight chips; PickRow device list; one boost toggle; the live activity graph kept).
- `docs/plans/2026-11-12-polish-plan.md` (D1–D7).
- The user's direction: "la referencia canónica debería ser ese plugin y converger a ese lenguaje visual … eliminar el drift de una vez por todas".

---

## 1. The design system (from crate-mark)

| Element | Rule |
|---|---|
| Surfaces | canvas `paper`, raised `paperLift`, popover (new token); 1 px hairline `line` (ink at 10% under Crate), quiet line `lineSoft` (6%); panel padding 16, section gap 16 |
| Text roles | primary `ink`; secondary (new, ink at 78%); muted `inkDim`; subtle (new); faint (new) |
| Accent | `sun` (accent), `sunHi`/`mark` (accentHi), thumb (new, sunHi toward ink) and beam tail (new, sun toward sunHi), both derived from the palette |
| Label | mono face, 11 px, tracking 0.14 em, uppercase. Tone `subtle` by default; `accent` for section heads and active state (crate-mark: "Crate" and "Equalizer" accent, "Presets" subtle) |
| Value | mono 12–13 px |
| Chip | 32 px, straight (radius 6 = `Tokens.radius`, chosen over the pill in the mock-ups), transparent, 1 px `line` edge; hover edge accentHi at 40%; on = filled accentHi with canvas ink; mono 12 |
| Pick row | full-width list row (devices, networks): icon, title over a sub line, radius 6, `line` edge; picked = `pickFill` wash, `pickEdge` edge, a 6 px accentHi dot with a halo |
| Toggle | a slim pill switch: hairline track, thumb knob, the accentHi track when on (D1 keeps switches, which crate-mark expresses as chips) |
| Icon button | 18 px glyph, no plate, 44 px hit area; secondary ink, accentHi on hover and when on |
| Button | confirm = filled accent (D4); navigate = outlined accent, 10% accent wash on hover |
| Beam | slider and progress: 1 px hairline track; 1 px gradient fill from accent at 14% to the beam tail; 8 px blurred trail; 4 px thumb-ink dot inside an 8 px accent halo; 6 px thumb shown only on hover or drag; optional over-range segment and mark (volume boost); non-interactive and indeterminate modes |
| Frame | popover fill, hairline edge, radius 6 (`Tokens.radius`); no doubled inner hairline |
| Live graph | the Controls activity graph stays: 1 px series lines, a gradient area under CPU, a hairline grid, a dot with a halo at each head, mono legend |
| Boost | a single toggle Chip; on extends the output Beam to 150 % with the over segment and the 100 % mark |
| Page head | one component: rule, seal, eyebrow, title (display face), blurb, optional right-hand register |
| Motion | 150 ms for state colour (`Tokens.snap` stays for presses) |

## 2. Decisions (binding for every wave)

1. **One switch.** A theme style sets `controls: "crate"` to opt into the whole geometry. Colours already follow the existing switches (`accentMarks`, `selectFill`, `labelAccent`, `navCaps`, `compact`). Fewer knobs, and no half-converged themes.
2. **Mono is a style key.** `mono` (Crate: "JetBrainsMono Nerd Font") stops a user `fontFamily` from overwriting the mono face while a style names one. This fixes `Tokens.qml:344`.
3. **`fMicro` is 11 under compact.** The label size equals crate-mark's.
4. **Captions get two tones.** A Label `tone` is `"subtle"`, `"accent"` or `"active"`. `labelAccent` keeps meaning "section heads in accent", and field captions become subtle. This replaces the all-cyan caption rule from Phase 1.
5. **Kit first, surfaces second.** No surface keeps a private slider, chip, toggle, icon button, label or progress. If a surface needs something the kit lacks, the kit grows it.
6. **The stock look is preserved.** Every change is gated on `Tokens.controlsCrate` (or the existing switches). A built-in theme renders as before, and each wave proves it with a capture.
7. **Islands are re-sourced, not rewritten.** The Ryogami picker and the PluginKit Theme take their roles from Tokens (the way `ryoshot/Singletons/Theme.qml` does), then swap their controls for kit ones.
8. **crate-mark dogfoods the kit.** Once Beam, Chip and Label exist, the plugin uses them. The reference and the kit can no longer disagree.

## 3. Global Constraints

- Ryoku commits: `[ryoku] area: summary`, no em-dashes, no AI attribution; run `.githooks/pre-commit` and `commit-msg` by hand.
- Tests:
  - every new style key gets a Go sanitiser test (`shell/ipc/usertheme_test.go`) and a `tests/qml/tst_themestyle.qml` case;
  - every new kit primitive with logic (Beam value, drag, clamp, over-range; Chip toggle) gets a qmltestrunner test written first.
- Live verification per wave: local `ryoku-desktop` and `ryoku-shell` packages (bump pkgrel; keep the previous one for rollback); captures under Crate and under Default for each touched surface.
- The crate-for-ryoku repo is public: no live-desktop captures or personal data in it.

## 4. Review Focus

1. Default (no style): every kit primitive and every migrated surface is pixel-equivalent to before.
2. Beam keeps the volume boost (over 100% segment and mark) and the OSD error overflow.
3. Toggles stay operable by keyboard (focus edges) after losing their plates.
4. A theme with `controls: "crate"` but a light palette stays legible (hairlines and subtle ink on paper).
5. Live theme switch restyles every primitive without a shell restart.

---

## Wave 0: Foundations (tokens and style keys)

**Files:** `ryoku/shell/ipc/usertheme.go` and `_test.go`, `ryoku/ui/Singletons/themestyle.js`,
`ryoku/ui/Singletons/Tokens.qml`, `tests/qml/tst_themestyle.qml`, `docs/store.md`;
crate-for-ryoku `theme/crate/scheme.json`.

- [ ] **Step 1: tests first.**
  - Go: `TestThemeStyleValuesKeepsControlsCrate` (only `"crate"` passes); `TestThemeStyleValuesKeepsMonoFace` (sanitised like `navFont`).
  - QML: `readStyle` cases for `controls` and `mono`.
  - Run them and watch them fail.
- [ ] **Step 2: style plumbing.** `readStyle` returns `controlsCrate` (bool) and `mono`.
- [ ] **Step 3: Tokens.**
  - New: `controlsCrate`, `inkSecondary` (ink at 0.78), `inkSubtle`, `inkFaint2`, `popover` (from `surfaceContainer` with a `paperLift` fallback), `thumb` (mix sunHi→ink 0.5), `beamTail` (mix sun→sunHi 0.5), `markHover` (mark at 0.4).
  - Fonts: `mono` honours the style's mono over `fontFamily`.
  - Sizes: compact `fMicro` = 11; `trackLabel` = `fMicro` × 0.14 under `controlsCrate`.
- [ ] **Step 4:** tests pass; `go test ./...` and the QML suite are green; qmllint clean.
- [ ] **Step 5:** Crate scheme gains `"controls": "crate", "mono": "JetBrainsMono Nerd Font"`. Commit to both repos.

## Wave 1: Kit primitives

**Files:** new `ryoku/ui/Beam.qml`, `Chip.qml`, `PickRow.qml`, `IconButton.qml`, `Label.qml`, `Divider.qml`,
`PageHead.qml` (promoted from `apps/ryovm/quickshell/PageHead.qml`, plus a `register` property);
restyled `Slid.qml`, `Seg.qml`, `Chips.qml`, `Multi.qml`, `IconBtn.qml`, `Sw.qml`, `Step.qml`,
`Btn.qml`, `SettingRow.qml`, `SettingCard.qml`, `Section.qml`, `Picker.qml`, `AppPicker.qml`,
`PickBar.qml`, `Gallery.qml`, `Tabs.qml`; the `ui/qmldir`; tests in `tests/qml/`.

- [ ] **Step 1: Beam test first** (`tst_beam.qml`). Cover:
  - value clamps to 0–1 and maps `from`/`to`;
  - a press at x sets value = x/width;
  - `interactive: false` ignores input;
  - `over` > 1 draws the over segment;
  - `indeterminate` runs a sweep that stops under reduced motion.
- [ ] **Step 2: Beam.** Port `Panel.qml:150-244` onto Tokens (`line`, `sun`, `beamTail`, `thumb`, `markHover`). Keep the API of `Slid` (`value`, `from`, `to`, `stepSize`, `moved`, `committed`) so `Slid` becomes a thin wrapper.
- [ ] **Step 3: Chip test and Chip.** Straight (radius `Tokens.radius`), `on`, `checkable`, `clicked`; mono 12; hover edge `markHover`. **PickRow:** `icon`, `title`, `sub`, `picked`, `clicked`.
- [ ] **Step 4: IconButton and Label.**
  - IconButton: an SVG path or font glyph, 18 px, 44 px hit area, `on`, focus edge.
  - Label: `tone` subtle/accent/active, mono `fMicro`, `trackLabel`, uppercase.
- [ ] **Step 5: Divider and PageHead.**
  - Divider: hairline, `quiet`.
  - PageHead: eyebrow, title, blurb, `register`.
- [ ] **Step 6: Restyle the existing kit behind `controlsCrate`.**
  - Slid → Beam.
  - Seg, Chips and Multi → Chip grammar.
  - IconBtn → plateless.
  - Sw → slim pill switch.
  - Step → plateless − and +.
  - Btn → outline per target.
  - SettingRow value → mono 12–13; revert → plateless.
  - SettingCard and Section → Label and Divider.
  - Picker, AppPicker and PickBar → popover, Label, unfilled hover.
  - Gallery → `pickEdge`.
  - Tabs off label → subtle.

  Each component's stock branch stays byte-for-byte the same.
- [ ] **Step 7: a kit gallery page** (in Kit: `plugins/kit` "Design system" tab). It renders every primitive in every state; it is the visual test bench for all later waves.
- [ ] **Step 8:** qmltestrunner suite and qmllint are green. Build packages; capture the gallery under Crate and Default; commit.

## Wave 2: Shell surfaces (task list)

- [ ] **services Theme:** gate on `styled`: `outline` → hairline, `borderWidth` → 1, `mono` → `Tokens.mono`. That retunes OSD, notifications, popouts, polkit, keyring and clipboard at once.
- [ ] **Sidebar (Controls):**
  - LevelSlider, MixerRow and ControlsSettingsPopup sliders → Beam (keep mute and exact value);
  - SidebarSegments → Seg; CornerButton and the mute plates → IconButton;
  - SidebarToggle, ConnectionTile radio and BrightnessDrawer link → Sw;
  - MixerDrawer chips → Chips; VitalMeter → Beam (non-interactive);
  - eyebrows → Label; SidebarFrame inner hairline and radius 15 → Frame rule.
- [ ] **OSD:** trough → Beam with an `over` error segment; window frame per the services Theme gate.
- [ ] **Notifications:** HeaderButton → IconButton; body face → ui; the rest is already gated.
- [ ] **Desktop and dock menus:** add a `styled` bridge to `desktop/Singletons/Theme.qml` (like overview); MenuSlider → Beam; MenuChip → Chip; MenuSection → Label.
- [ ] **Polkit and keyring:** OK and Cancel → Btn (drop the `#fdeee6` literal); fields → Field; checkbox → Sw or Chip.
- [ ] **Clipboard:** radius, 2 px selected borders → `pickEdge` 1 px; star and delete → IconButton.
- [ ] **Music and calendar popouts:** MusicPopout and MusicHoverPopout progress → Beam; TButton and Ctl → IconButton; HFader → Beam; PopoutChip → Chip; MicroLabel and Eyebrow → Label.
- [ ] **Dock:** TBtn → IconButton; 8–9 px labels → Label.
- [ ] **Overview:** fixed tracking → `trackLabel`; faces → `navFont`; 2 px active borders → 1 px `pickEdge`.

## Wave 3: QS bar (task list)

- [ ] **Theme.qml:** under `styled`, read `Tokens` for `hairline` (`line`), `raised` (`paperLift`), `accentHi` (`sunHi`), `subtle`, and the frame (`panelBorder` → hairline, `bg` → popover). This is the two-line frame fix, and the shared surface feeds all 18 panels.
- [ ] **`modules/PanelCard.qml`:** frame column, 16/16 padding (12 under compact), header Label in the accent tone and an IconButton close. Replaces the 17 pasted headers, 14 ✕ glyphs and 38 inline dividers.
- [ ] **Beam:** replaces the 10 pasted 8 px bars, the 3 variants and the 3 sliders. Volume keeps its boost through `over`, and Mpris seek is interactive.
- [ ] **Chip:** replaces the ~41 seal tiles and 13 primary buttons; the 4 toggle shapes become Sw or Chip.
- [ ] **Label and an `InfoRow` kit row:** replace the 4 caption sizes, 2 InfoRows and ~17 inline rows. This also absorbs Phase 2a's `sectionInk`.
- [ ] **IconButton:** replaces TransportButton, the info "!" plate, the chevron well and the dismiss ✕.

**Wave 3 status (2026-11-13).** The 17 panel bodies, the dashboard, the tooltip and QS Bar Settings are on
the kit (fork commits 8e2e81bd..06fc9f71). Rulings from the user: every crate floating surface uses the
shared glass (Tokens.glass plus compositor blur, no filled drop shadow under it) and the 6 px
`Tokens.radius` corner; QS Bar Settings opens with the panels' `CrateResourceHeader` line and flat
`SettingCard` groups (which also converges the Hub); Japanese glosses follow `showJapaneseGloss` in
either look. `CrateResourceHeader` stands in for the planned `PanelCard`. **Deferred to a later wave:**
the image and media pickers (`ImageCarousel*`, `MediaBrowser*`), all three layouts each.

## Wave 4: Apps (task list)

- [x] **Hub:** the 22 page-header copies and 4 variants → PageHead (with `register` for ControlsPage); the 8 bespoke chips → Chip or Chips; the 4 progress copies → Beam; RowTool → IconButton; SectionHead and Head → Label. Delete the dead `hub/quickshell/Singletons/Theme.qml`.
- [x] **Ryostore:** InstallProgress → Beam (indeterminate); ProviderTabs → Tabs; LinkChip → IconButton; the AppsHero Chip → Chip; ProductCard and AppsTile → a kit `PickCard`; search fields → Field.
- [x] **Ryovm:** PageHead → kit; DownloadStack → Beam (delete the dead `Progress.qml`); LabelText, FieldLabel, Head and SectionMark → Label; the card plates → PickCard.
- [x] **Ryoshot:** Slider → Beam; IconButton → kit; drop `radius*2` and the 6–9 px radius literals.
- [x] **Welcome:** PageTitle → PageHead; the step rail → Tabs (the Beam under it was dropped, see status).

**Wave 4 status (2026-11-14).** The Hub, Ryostore, Ryovm (Ryoport), Ryoshot and Welcome are on the kit
(fork commits 17edf2ed..e6f5ce16), installed live as ryoku-desktop 1.0.9.r6221 and reviewed by the user
app by app. New kit pieces: `PickCard` (a picked card takes the pick wash, the 1 px `pickEdge` and a corner
dot), keyed Tabs with counts, a Field leading glyph, a bipolar Beam. Rulings from the user: selection is
filled with the mark everywhere (the Hub-only outline variant is gone); large working windows (Hub,
Ryostore, Ryovm, Welcome) are opaque `Tokens.popover`, no glass; Ryoku marginalia (corner ticks, lead
bars, barcodes, framed seals) do not appear under crate; a step rail is marked by its tab underline
alone, with no progress beam under it. Residuals: about a dozen Ryoshot tools have no Solar glyph and
keep their own line icons; Ryostore's GitHub and Discord links use generic Solar glyphs; the kit Field
keeps its 2 px focus border (about 250 callers). Two Ryostore probes (`ryostore-components`,
`ryostore-handoff`) failed before the wave and still do.

## Wave 5: Islands (task list)

- [ ] **Ryogami picker:** `theme/Theme.qml` roles and type scale come from Tokens (keep the preset palettes as content); add the mono face; FolioSlider → Beam; Switch → Sw; RiceChip, QuietChip, MiniSeg, BrowserChip and ResetChip → Chip; SectionLabel → Label.
- [ ] **PluginKit:** `Singletons/Theme.qml` font, mono, line and radius from Tokens; `MicroLabel` → Label; `WaveMeter` stays as a distinct visual, documented as allowed.
- [ ] **crate-mark:** use the kit Beam, Chip, IconButton and Label (dogfooding); its local copies go.

## Wave 6: Guard and close-out

Decided with the user on 2026-11-14:
- The reload cover takes its mark from the theme (option 1), not from the rice's brand layer or a rice reload-cover asset.
- The cover carries a Japanese gloss in all three states: 再読込 (shell reload), 起動中 (boot), 失敗 (failure), shown when `showJapaneseGloss` is on.
- The Ryogami picker stays as shipped in Wave 5: no 力 seal under crate.
- The refreshed Crate rice ships no brand layer: applying it keeps the user's own name and mark (力 by default).

- [ ] **Reload cover** (`ryoku/shell/quickshell/reload-cover`, the "SHELL RELOADING" / "LOADING DESKTOP" screen; asked for by the user 2026-11-14). Under `Tokens.controlsCrate` only:
  - iris and hold fill `Tokens.paper` instead of black;
  - the mark comes from a new theme style key `coverMark` (an SVG path relative to the theme directory; crate-for-ryoku ships `theme/crate/cover-mark.svg`, the monochrome Crate mark), drawn emblem-sized (about 96 px) and tinted with the theme's ink, in place of the 928 px-wide Ryoku wordmark `assets/logo.png`;
  - the status line is a kit `Label` (mono 11, tracking 0.14 em, subtle) with its gloss;
  - an indeterminate `Beam` under the line during the "hold" phase only (real waiting, not decoration);
  - the failure line in the theme's error role, mono.

  Stock unchanged; a user's own cover (Hub > Desktop > Reload cover, `brand.json` `reloadCover`) still wins. Boot covers map before the shell: an offscreen probe proves the first frame already carries the theme under both looks. Tests: Go sanitiser test and `tst_themestyle.qml` case for `coverMark`; a reload-cover probe for Crate and Default.
- [ ] **Bar marks CRATE and the Crate glyph** (asked for by the user 2026-11-14): `crate` joins `launcherLogoTextOptions` (the "CRATE" wordmark) and `launcherLogoIconOptions` (the monochrome Crate mark), right after `ryoku`, in both looks, selectable in QS Bar Settings > Identity. The Crate mark is not a font glyph, so a `LauncherMark.qml` in qsbar/modules draws font glyphs as text and `crate` as the logo's outline path (the one crate-mark's `CrateLogo.qml` uses), tinted with the seal; the bar and the Identity picker both use it. Tests: an offscreen probe (both lists hold `crate`; vector for `crate`, text otherwise) and Go `bar set launcher launcherLogoText|launcherLogoIcon crate` cases.
- [x] **Wallpapers** (2026-11-14): Groove and Sheen, flat (3840x2160 and 3840x2400); Horizon, Handoff and Macro are retired, and six other directions sketched that day (mark, mood map, EQ, genre wheel, topology, spectrum) were declined. A five-wallpaper set with Stage depth layers (`2026-11-14-wallpaper-set-design.md`) was tried and shelved: the user rejected the new motifs and the parallax motion. To revisit later with a different approach.
- [x] **Crate rice refresh** (2026-11-14, done): the bar block is the live one (launcher first; crate-mark on the right after quick; the user's widgets, colours, corners and picker), the CRATE wordmark on (`launcherLogoText`/`launcherLogoIcon` crate, which the fork now keeps in shell.json, f3c7b9ac), every AI tool offered, no brand layer; proved by `ryoku-hub rice apply crate` on an isolated copy. The rest of the rice was already current.
  Original note: `rice/crate/rice.json` was captured on Ryoku 1.0.7, before Waves 0 to 5 (an older bar layout and widget set; its theme attributes, radius 8 and border 2, match the live desktop and are not the kit's 6 px `Tokens.radius`). Re-capture it from the approved live desktop (the user's bar as it is now: launcher first on the left, crate-mark on the right after `quick`; not crate-mark first), with the "CRATE" wordmark on (`launcherLogoMode` text, `launcherLogoText` crate). Strip anything personal, keep it without a brand layer, and prove it on a fresh, session-isolated apply. The contact sheet below is taken from that fresh apply, not from the development machine.

- [x] **`tools/design-lint`** (done 2026-11-14 as `bin/ryoku-dev-design-lint`, fork b916403e; baseline 519 files: 1434 hex colours, 1363 literal sizes, 35 control names, 12 hand-made bars, 8 sliders) (a Python script in the Ryoku repo), run by `.githooks/pre-commit`. It flags new QML outside `ui/` that:
  - defines a slider (`QQC.Slider`) or a progress bar (a Rectangle `width: … * value` pattern);
  - hard-codes `font.pixelSize` or a hex colour in shell, app or bar code;
  - defines a component named `*Chip`, `*Slider` or `*Progress`.

  The current debt goes in a shrink-only allowlist file, so debt can only go down.
- [x] **Contact sheet** (done 2026-11-14: 62 surfaces in both looks from tests/visual/surfaces, shown to the user; `brightness` and `shell-states` do not render offscreen, to investigate in the harness): every surface under Crate and Default, compared with crate-mark; record residual exceptions with a reason.
- [x] **Final** (done 2026-11-14): a fresh review found no Critical and three Important, fixed with tests (fork 2f466df5 cover falls back to the wordmark when the mark fails; 19e8c00c bar glyphs fall back on an older kit; a5fbab36 a rice naming no launcher marks gets Ryoku's). Deferred minors for the user:
  - AudioOutput.js: a single analog-stereo node that switches ports (non-UCM laptops) always reads "speaker"; a desktop with a "Speaker" PCI port reads "laptop"; Bluetooth headphones without form factor read as a remote speaker (fix: read the active port, gate "laptop" on a battery).
  - design-lint: counts the working tree, not the staged blob; skips renames; never prunes deleted files; misses ternary sizes, named colours, Qt.rgba and 3-digit hex; not in CI.
  - coverMark rejects a symlinked file (stow-style theme installs).
  - Beam's scan end is fixed at start: a track resized mid-scan or narrower than 24 px can still overflow.
  - The stock cover now imports QtQuick.Effects (Qt 6.5+).
  - install.sh still says "Ryoku 1.0.7+" though the CRATE mark and coverMark need the fork.

## Wave 7: Remaining surfaces (task list)

Inventory of 2026-11-14 (every module that opens its own window, checked for any crate adaptation): the user ruled that all of them migrate, in any order. Scope ruling (2026-11-14): Crate for Ryoku is a complete, closed package; it migrates what the Crate setup uses (QS Bar, the dynamic-island dock, the hero launcher and every shared surface) and NOT the alternative styles: the Python, Orpheus, Nomarchy and Kairos bars, the iRiS bar, the ii dock and the launcher's other variants (main, okshell, kairos, spotlight, python). Each surface follows the rulings in sections 1-2 and the Wave 3-5 patterns (kit primitives, Tokens roles, `Tokens.controlsCrate` gates, stock unchanged, one glass for floating panels, opaque large working windows, no Ryoku marginalia, kanji glosses kept), with a probe or scene for both looks.

- [x] **Game Bar** (fork 78836dac, a5b36985 all Solar, e08105a2 16 px card padding, 33f9baa0 kit danger Btn, 5df2dc9a danger stops + Tabs/Seg at the bar scale; glass over the game kept) (`shell/modules/gamebar`, 23 files, kit in 10).
- [x] **Ask** (fork 96f3205c + d2dceaa0, merged cd99e741; drawers opaque; Chip gains swatch) (`shell/modules/ask`: AskBar, AskBubble; Rashin's question bar).
- [x] **Capture overlays** (fork fef3f416, merged 41cededa; readout tags opaque popover, not glass: the camera layer redraws every frame) (`shell/modules/capture`: region, camera, keypress, recording).
- [x] **Ryoku launcher** (hero variant: fork d3444e4c, merged 8f47a7f7; ledger numerals hidden as marginalia; hero art kept as content) (`shell/modules/launcher`: hero launcher, window rail; 39 literal colours). Crate Palette users skip it, but a fresh install shows it.
- [x] **Keys** and **Keys hint** (fork 7f8634a5 + d27b89b2 phone-tab Solar glyphs, merged 8926ddc4; the user keeps the blurred scrim behind Kit in both looks) (`shell/quickshell/keys`, `keys-hint`).
- [x] **Phone bridge** (no chrome: services only; its notifications are the Wave 2 cards. The card's last-resort Material icon still needs a crate glyph) (`shell/modules/phone`).
- [x] **Ryopin** (fork 868cbd12, merged; strip is glass in the margin, card opaque, pin margin 44 px under crate) (`shell/quickshell/ryopin`, pinned windows).
- [x] **Visualizer** (fork 0b737130 + 74160cfd wallpaper relight kept, merged 9b082546) (`shell/modules/visualizer`; 5 literal colours).
- [x] **Shima dock** (the Crate setup's dock: `dock.design = shima`, drawn by inir/modules/iris/dock/IrisDockSurface; in progress). The Crate rice now carries the dock's look (shima, bottom, autohide, frost, labels, no magnify) without pinned apps; the fork keeps the user's pins when a rice names none (70c017ed).
- [x] **QS Bar image and media pickers** (fork f1d18832, merged f44ed8a7; tanzaku and hearthstone scrims glass; carousel slices keep their skewed corners).
- [x] **iNiR shared surfaces**: none can show in the Crate setup (iRiS bar or ii dock only); the notification card's fallback thumbnail is a kit glyph (fork f40f6e99, merged 214e272e).
- [x] **Desktop widgets and edit mode** (Stage: edit chrome, widget frame and every family, ~130 Solar glyphs; merged f356bd54) (`stage/modules/ii`: notes, clocks and the rest, the edit chrome; 244 files, 53 literal colours).
- [-] **iRiS bar**: out of scope (alternative style, scope ruling above).
- [x] The overview backdrop has no chrome of its own.

## Ordering and verification

Wave 0 → Wave 1 → Waves 2 and 3 (independent once the kit exists) → Wave 4 → Wave 5 → Wave 6 → Wave 7.
Each wave ends with packages installed live and a capture review with the user before the next starts.

## V1 closed (2026-11-14)

Diego closed V1 after testing fork packages 1.0.9.r6294.gfca21d8 live. Late fixes in that batch: every QS Bar
panel is the one glass whatever the bar's opacity (ef1f28f8); one shared glyph for the current audio output in the
bar, the volume panel and the media panel (a90ccf68, 4761a687); the shima dock under crate is a minimal glass body
behind the icons, no edge, plates or separator (fca21d8a). The live kit overlay is off: changes ship as matching
packages. Next: publishing (pushes, AUR, Ryostore, a release) on Diego's go, then the ryoku.cratemusic.app site
(crate repo docs/plans/2026-11-14-ryoku-site-plan.md).
