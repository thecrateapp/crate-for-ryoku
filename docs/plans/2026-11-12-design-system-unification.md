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
| Chip | 32 px pill (radius 16), transparent, 1 px `line` edge; hover edge accentHi at 40%; on = filled accentHi with canvas ink; mono 12 |
| Toggle | a slim pill switch: hairline track, thumb knob, the accentHi track when on (D1 keeps switches, which crate-mark expresses as chips) |
| Icon button | 18 px glyph, no plate, 44 px hit area; secondary ink, accentHi on hover and when on |
| Button | confirm = filled accent (D4); navigate = outlined accent, 10% accent wash on hover |
| Beam | slider and progress: 1 px hairline track; 1 px gradient fill from accent at 14% to the beam tail; 8 px blurred trail; 4 px thumb-ink dot inside an 8 px accent halo; 6 px thumb shown only on hover or drag; optional over-range segment and mark (volume boost); non-interactive and indeterminate modes |
| Frame | popover fill, hairline edge, radius 6 (`Tokens.radius`); no doubled inner hairline |
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

**Files:** new `ryoku/ui/Beam.qml`, `Chip.qml`, `IconButton.qml`, `Label.qml`, `Divider.qml`,
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
- [ ] **Step 3: Chip test and Chip.** Pill, `on`, `checkable`, `clicked`; mono 12; hover edge `markHover`.
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

## Wave 4: Apps (task list)

- [ ] **Hub:** the 22 page-header copies and 4 variants → PageHead (with `register` for ControlsPage); the 8 bespoke chips → Chip or Chips; the 4 progress copies → Beam; RowTool → IconButton; SectionHead and Head → Label. Delete the dead `hub/quickshell/Singletons/Theme.qml`.
- [ ] **Ryostore:** InstallProgress → Beam (indeterminate); ProviderTabs → Tabs; LinkChip → IconButton; the AppsHero Chip → Chip; ProductCard and AppsTile → a kit `PickCard`; search fields → Field.
- [ ] **Ryovm:** PageHead → kit; DownloadStack → Beam (delete the dead `Progress.qml`); LabelText, FieldLabel, Head and SectionMark → Label; the card plates → PickCard.
- [ ] **Ryoshot:** Slider → Beam; IconButton → kit; drop `radius*2` and the 6–9 px radius literals.
- [ ] **Welcome:** PageTitle → PageHead; the step rail → Tabs plus Beam.

## Wave 5: Islands (task list)

- [ ] **Ryogami picker:** `theme/Theme.qml` roles and type scale come from Tokens (keep the preset palettes as content); add the mono face; FolioSlider → Beam; Switch → Sw; RiceChip, QuietChip, MiniSeg, BrowserChip and ResetChip → Chip; SectionLabel → Label.
- [ ] **PluginKit:** `Singletons/Theme.qml` font, mono, line and radius from Tokens; `MicroLabel` → Label; `WaveMeter` stays as a distinct visual, documented as allowed.
- [ ] **crate-mark:** use the kit Beam, Chip, IconButton and Label (dogfooding); its local copies go.

## Wave 6: Guard and close-out

- [ ] **`tools/design-lint`** (a Python script in the Ryoku repo), run by `.githooks/pre-commit`. It flags new QML outside `ui/` that:
  - defines a slider (`QQC.Slider`) or a progress bar (a Rectangle `width: … * value` pattern);
  - hard-codes `font.pixelSize` or a hex colour in shell, app or bar code;
  - defines a component named `*Chip`, `*Slider` or `*Progress`.

  The current debt goes in a shrink-only allowlist file, so debt can only go down.
- [ ] **Contact sheet:** every surface under Crate and Default, compared with crate-mark; record residual exceptions with a reason.
- [ ] **Final:** a fresh whole-branch review; the rulings and deferred minors go to the user.

## Ordering and verification

Wave 0 → Wave 1 → Waves 2 and 3 (independent once the kit exists) → Wave 4 → Wave 5 → Wave 6.
Each wave ends with packages installed live and a capture review with the user before the next starts.
