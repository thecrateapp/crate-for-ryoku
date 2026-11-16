# Crate lock screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship two qylock lock-screen skins for Crate for Ryoku, `crate/hero` and `crate/orbit`, selectable in Ryoku Settings › Lockscreen, with a safe preview tool, offscreen tests, packaging and CI.

**Architecture:** Skins live in `lockscreen/crate/{common,hero,orbit}`; `common/` is a QML directory module both skins import as `"../common"` in source and that `package/build.sh` vendors into each built skin. Everything that touches the session (MPRIS) sits behind a Loader that only runs in the session lock. Tests and the preview load a skin offscreen in a `ShellRoot` with a fake `sddm`, a stub `Ryoku.Ui.Singletons` and a fake player, like Ryoku's `tests/lock-*.sh`.

**Tech Stack:** QML (Qt 6, Quickshell `qs`), bash, Python 3 (fontTools for WOFF2 → TTF), GitHub Actions (Arch container).

**Spec:** `docs/plans/2026-11-16-crate-lock-screens-design.md`

## Global Constraints

- Canvas `#0a0a0f`; text `#f1f5f9`; secondary `rgba(241,245,249,0.62)`; faint `rgba(241,245,249,0.42)`; hairline `rgba(241,245,249,0.1)`; cyan `#06b6d4`, cyan-hi `#67e8f9`; danger `#ef4444`; radius 6.
- Display: Bricolage Grotesque 800; labels: JetBrains Mono uppercase, letter spacing 0.12–0.14 em.
- Skin slugs: `crate/hero` (rice default) and `crate/orbit`. Install dir: `${XDG_DATA_HOME:-~/.local/share}/qylock/themes/crate/<name>/`.
- theme.conf keys: `showNowPlaying` (`true`/`false`, default `true`), `background` (`groove`/`sheen`, default `groove`).
- Never import `Quickshell.Services.Mpris` from a file that SDDM loads; MPRIS only via a Loader gated on `sessionLock`.
- Session-lock detection: `sessionLock = typeof sddm !== "undefined" && sddm.fingerprintHint !== undefined`.
- Skins never authenticate: they call `sddm.login(user, password, sessionIndex)` / `sddm.loginKeyPin(user, pin)` and react to `sddm.loginFailed` / `sddm.loginSucceeded`.
- Strings go through `I18n.tr()` (common/i18n, English base). No emojis.
- Motion only on real transitions; none when `reduceMotion` (Tokens.reduceMotion when available, else false).
- The preview tool and tests never create a `WlSessionLock` and never run `ryoku-shell lock`, `ryoku-qylock-lock` or `loginctl lock-session`.
- English for code, commits and docs; commits in this repo's style (`feat(lockscreen): …`).

## Review Focus

1. A wrong password followed by a correct one: the red state clears as soon as typing resumes; success leaves no error on screen.
2. Long names (user, host, track title, artist): elided on one line, never overlapping the clock or the field, at 1366x768 and 3840x2400.
3. Crate stops or quits while locked: the now-playing block disappears with no QML errors; it returns if Crate plays again.
4. After clicking the user name or a power link, typing still lands in the password field.
5. Security key asks for a PIN: Enter sends `loginKeyPin`, not `login`, and the hint says so.

---

## File Structure

```
lockscreen/
  crate/
    common/
      qmldir                     module "common": CratePalette (singleton), Background, PasswordField,
                                 AuthHint, PowerRow, UserSwitch, NowPlaying, NowPlayingMpris, ErrorLine
      CratePalette.qml           tokens + fonts (FontLoader) + scale factor helper
      Background.qml             Groove/Sheen image + veil
      PasswordField.qml          field, states, nudge
      AuthHint.qml               hint text from fingerprint/key/auth state
      PowerRow.qml               Suspend · Reboot · Shut down
      UserSwitch.qml             current user, click to cycle
      NowPlaying.qml             view; takes a `player` object
      NowPlayingMpris.qml        finds org.mpris.MediaPlayer2.crate, exposes `player`
      i18n/qmldir, i18n/I18n.qml English base, tr(key)
      fonts/                     BricolageGrotesque.ttf, JetBrainsMono-Regular.ttf, OFL.txt (built)
      backgrounds/               groove.webp, sheen.webp (built)
    hero/Main.qml, theme.conf, metadata.desktop
    orbit/Main.qml, OrbitDial.qml, theme.conf, metadata.desktop
  preview.sh                     window or --shot PNG; states
  tests/
    harness/                     ShellRoot fixtures: FakeSddm.qml, FakePlayer.qml, stub Ryoku/Ui/Singletons
    run.sh                       runs every lock-crate-*.sh
    lock-crate-*.sh + .qml       one behaviour per pair, PASS/FAIL output
package/build.sh, install.sh, uninstall.sh   (modify)
rice/crate/rice.json             (modify) assets.lock
NOTICE, README.md                (modify)
.github/workflows/lockscreen.yml (create)
```

### Interfaces used across tasks

- `CratePalette` (singleton): colour properties `canvas, text, secondary, faint, hairline, cyan, cyanHi, danger`, `radius`, `displayFamily`, `monoFamily`, `function s(px: real): real` (scales by `Screen.height / 1200`), `reduceMotion: bool`.
- `PasswordField { user: string; sessionIndex: int; keyState: string; state: "idle"|"typing"|"checking"|"error"; errorText: string; signal submitted(); function clear() }` — calls `sddm.login` or, when `keyState === "pin"`, `sddm.loginKeyPin`.
- `NowPlaying { player: var /* {title, artist, artUrl, position, length, playing} or null */; compact: bool }` — hidden when `player` is null or `!player.playing`.
- Main.qml root (both skins) exposes `property bool clock24h`, `property var clockLocale`, `property bool sessionLock`, `property var config` (read from theme.conf by qylock), `property date now` (tests can set it).
- Test fixture: `ShellRoot { property var sddm; property var config; property var userModel; Loader { source: <skin>/Main.qml } }`; each test prints `PASS: <name>` or `FAIL: <reason>` then `Qt.quit()`; the `.sh` greps like Ryoku's `tests/lock-time-format.sh`.

---

### Task 1: Harness, common module skeleton and `crate/hero` that loads in both modes

**Files:**
- Create: `lockscreen/tests/harness/{FakeSddm.qml,FakePlayer.qml}`, `lockscreen/tests/harness/imports/Ryoku/Ui/Singletons/{qmldir,Tokens.qml,TimeFormat.qml}` (stubs: `controlsCrate: false`, `reduceMotion: false`, `TimeFormat.is24h: true`)
- Create: `lockscreen/tests/run.sh`, `lockscreen/tests/lock-crate-load.{sh,qml}`
- Create: `lockscreen/crate/common/{qmldir,CratePalette.qml,Background.qml,i18n/qmldir,i18n/I18n.qml}`
- Create: `lockscreen/crate/hero/{Main.qml,theme.conf,metadata.desktop}`
- Create: `lockscreen/build-assets.sh` (fonts WOFF2→TTF via fontTools, backgrounds via `wallpaper/groove.py 3840 2400 <out>` and `sheen.py`, into `common/fonts` and `common/backgrounds`; both dirs git-ignored)

**Interfaces:** Produces `CratePalette`, `Background { kind: "groove"|"sheen" }`, the fixture contract above.

- [ ] **Step 1: Write `lock-crate-load.qml`** loading `hero/Main.qml` twice: with `FakeSddm { fingerprintHint: false }` (session lock) and with a plain object lacking `fingerprintHint` (SDDM). Assertions: `item.sessionLock === true` then `false`; `CratePalette.displayFamily` resolves to a loaded family (FontLoader status Ready); `Background.source` ends with `groove.webp` by default and `sheen.webp` with `config.background = "sheen"`; no `QQmlComponent` errors in output. Print `PASS: hero loads in lock and SDDM`.
- [ ] **Step 2: Run `bash lockscreen/tests/run.sh`** — Expected: FAIL (`theme did not load`).
- [ ] **Step 3: Implement** the files above. `run.sh` mirrors Ryoku's `tests/lock-time-format.sh`: temp dir, `QT_QPA_PLATFORM=offscreen`, `QML_IMPORT_PATH` = harness imports, `timeout 15s qs -p`, grep PASS/FAIL; it runs `build-assets.sh` first if `common/fonts` is missing. Hero Main.qml at this stage: Background + an empty layout; reads `config.background` with fallback `groove`.
- [ ] **Step 4: Run `bash lockscreen/tests/run.sh`** — Expected: `PASS: hero loads in lock and SDDM`.
- [ ] **Step 5: Commit** — `feat(lockscreen): Crate skin skeleton, assets and offscreen harness`

### Task 2: Password field and the auth flow

**Files:**
- Create: `lockscreen/crate/common/{PasswordField.qml,AuthHint.qml,ErrorLine.qml}`
- Modify: `lockscreen/crate/hero/Main.qml`
- Test: `lockscreen/tests/lock-crate-auth.{sh,qml}`

**Interfaces:** Consumes `CratePalette`. Produces `PasswordField`, `AuthHint { fingerprintState; keyState; authState }`.

- [ ] **Step 1: Write `lock-crate-auth.qml`**. Assertions, in order: typing "hunter2" + Enter calls `FakeSddm.login("diego", "hunter2", 0)` once and the field state is `"checking"` (disabled); `sddm.loginFailed()` → state `"error"`, field text `""`, ErrorLine visible with colour `#ef4444` and the PAM text set on FakeSddm (`"Authentication failure"`); typing one char → state `"typing"`, ErrorLine hidden (Review Focus 1); `sddm.loginSucceeded()` → no visible error; with `FakeSddm.keyState = "pin"`, Enter calls `loginKeyPin("diego", <pin>)` and not `login`, and the hint reads `I18n.tr("SECURITY KEY PIN")` (Review Focus 5); `fingerprintState = "scanning"` → hint `"or touch the reader"` in cyan-hi, `"fail"` → danger. Empty Enter does not call `login`.
- [ ] **Step 2: Run** `bash lockscreen/tests/run.sh` — Expected: FAIL on `lock-crate-auth`.
- [ ] **Step 3: Implement** PasswordField (single underline, cyan focused / danger error, mono bullets, cyan caret, one sideways nudge on error unless `reduceMotion`), AuthHint, ErrorLine; wire into hero bottom-right with "PASSWORD" label.
- [ ] **Step 4: Run** — Expected: both PASS.
- [ ] **Step 5: Commit** — `feat(lockscreen): password field, hints and auth states`

### Task 3: User switching and the power row

**Files:**
- Create: `lockscreen/crate/common/{UserSwitch.qml,PowerRow.qml}`
- Modify: `lockscreen/crate/hero/Main.qml`
- Test: `lockscreen/tests/lock-crate-user-power.{sh,qml}`

**Interfaces:** Produces `UserSwitch { model: userModel; currentUser: string }`, `PowerRow { }` (calls `sddm.suspend/reboot/powerOff`).

- [ ] **Step 1: Write the test.** Assertions: with a one-user model the name shows `userModel.lastUser` and is not clickable; with two users a click cycles `currentUser` and the next Enter logs in as the new user; clicking Suspend/Reboot/Shut down calls the matching FakeSddm function once; after each click `PasswordField` has `activeFocus` (Review Focus 4).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement**; power links in mono with Crate's hover underline (1 px cyan-hi, scaleX 0→1 from the left).
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(lockscreen): user switch and power row`

### Task 4: Now playing behind the session-lock gate

**Files:**
- Create: `lockscreen/crate/common/{NowPlaying.qml,NowPlayingMpris.qml}`
- Modify: `lockscreen/crate/hero/Main.qml`
- Test: `lockscreen/tests/lock-crate-nowplaying.{sh,qml}`

**Interfaces:** Consumes `FakePlayer` in tests. Produces `NowPlaying { player; compact }`; Main.qml: `Loader { active: sessionLock && showNowPlaying; source: "../common/NowPlayingMpris.qml" }` exposing `player`.

- [ ] **Step 1: Write the test.** Assertions: session lock + FakePlayer playing ("Blending", "High Vis") → block visible with both texts and a progress width proportional to position/length; `config.showNowPlaying = "false"` → hidden; SDDM mode → the Mpris loader is inactive (its `status` is `Loader.Null`) and nothing references Mpris; player set to `null` mid-test → hidden, no warnings in output; title of 200 chars → elided, block bounds do not intersect the password field (Review Focus 2, 3).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement**: NowPlayingMpris picks the player whose `dbusName` ends with `.crate`; NowPlaying (hairline top rule, 72 px cover radius 6, "NOW PLAYING IN CRATE" label, title Bricolage 700, artist secondary, 2 px cyan-hi progress).
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(lockscreen): now playing from Crate in the session lock`

### Task 5: Hero clock, date and header

**Files:**
- Modify: `lockscreen/crate/hero/Main.qml`
- Test: `lockscreen/tests/lock-crate-hero-clock.{sh,qml}`

- [ ] **Step 1: Write the test.** With `now = 2026-12-06 23:05` and `clockLocale` en_US: 24 h shows `"23:05"`; 12 h shows `"11:05"` and `"PM"`; date line `"SUNDAY"` and `"06 DEC 2026"` (mono, day in cyan-hi); header `"LOCKED"` and the host from `sddm.hostName`; at 1366x768 and 3840x2400 the clock, now-playing block and field do not overlap (Review Focus 2).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** per spec (clock Bricolage 800 ≈ `s(300)`, tight tracking; a changed digit slides 120 ms unless `reduceMotion`).
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(lockscreen): hero clock, date and header`

### Task 6: `crate/orbit`

**Files:**
- Create: `lockscreen/crate/orbit/{Main.qml,OrbitDial.qml,theme.conf,metadata.desktop}`
- Test: `lockscreen/tests/lock-crate-orbit.{sh,qml}`

**Interfaces:** Consumes every common component; NowPlaying with `compact: true` renders the one-line form ("NOW PLAYING · Artist — Title").

- [ ] **Step 1: Write the test.** Runs the Task 1, 2, 4 and 5 assertions that apply against `orbit/Main.qml` (factor them into a shared `harness/SkinChecks.js` called with the skin path), plus: dial rotation equals `-(minutes/60)*360` degrees for `now`; the minute label shows `"05"`; the sign-in column is right-aligned; no `windup` or blast objects exist.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** OrbitDial (60 ticks, majors every 5 with mono numbers, bleeding off the left edge, current minute in cyan-hi) and the orbit layout per spec.
- [ ] **Step 4: Run** — Expected: all PASS for both skins.
- [ ] **Step 5: Commit** — `feat(lockscreen): crate/orbit skin`

### Task 7: Preview tool and gallery previews

**Files:**
- Create: `lockscreen/preview.sh`, `lockscreen/tests/lock-crate-preview.sh`
- Modify: `.gitignore` (preview output)

**Interfaces:** `preview.sh <crate/hero|crate/orbit> [idle|typing|checking|error|fp-scanning|fp-success|fp-fail|key-pin|key-touch|no-music|sddm] [--shot out.png] [--size WxH]`; reuses the harness fixtures.

- [ ] **Step 1: Write `lock-crate-preview.sh`**: for each skin and each state, `preview.sh … --shot` exits 0 and writes a PNG of the requested size whose pixels are not all one colour; it never starts `WlSessionLock` (grep the generated shell for `WlSessionLock` → none).
- [ ] **Step 2: Run** — Expected: FAIL (no preview.sh).
- [ ] **Step 3: Implement**: windowed mode opens a `FloatingWindow` with the skin; `--shot` renders offscreen and `grabToImage`s to the path.
- [ ] **Step 4: Run** — Expected: PASS. Then render `idle` and `error` for both skins at 1920x1200 and show them to Diego for review before Task 8.
- [ ] **Step 5: Commit** — `feat(lockscreen): preview tool and shots`

### Task 8: Packaging, install/uninstall and the rice

**Files:**
- Modify: `package/build.sh` (build skins: copy `hero`, `orbit`, vendor `common` into each as `common/`, rewrite `import "../common"` → `import "common"`, run `build-assets.sh`, render `preview.gif` from `preview.sh --shot` frames with Pillow)
- Modify: `package/install.sh`, `package/uninstall.sh`, `rice/crate/rice.json`, `NOTICE`, `README.md`
- Test: `lockscreen/tests/package-lock-skins.sh` (bash, temp `HOME`/`XDG_*`)

**Interfaces:** Install records the previous skin in `$STATE/previous-lock` (written once, only if the active skin is not `crate/*`); uninstall runs `ryoku-hub lock set "$(cat previous-lock || echo clockwork/orbital)"` only when the active skin (`~/.config/qylock/theme`) starts with `crate/`.

- [ ] **Step 1: Write the test**: build into a temp dist; assert `dist/…/lockscreen/crate/{hero,orbit}/{Main.qml,theme.conf,metadata.desktop,preview.gif,common/qmldir,common/fonts/BricolageGrotesque.ttf,common/backgrounds/groove.webp}` exist and no file under the built skins contains `../common`; run install with a stub `ryoku-hub` on PATH and temp HOME: skins land in `$XDG_DATA_HOME/qylock/themes/crate/`, `previous-lock` holds the prior slug; set active to `crate/hero`, run uninstall: stub records `lock set clockwork/orbital` (or the recorded one) and the skins are gone; with active `windows_7`, uninstall does not call `lock set`. `rice.json` has `assets.lock == "crate/hero"` (python json check).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement**; NOTICE lists Bricolage Grotesque and JetBrains Mono (SIL OFL 1.1) and the Groove/Sheen renders.
- [ ] **Step 4: Run** the package test and `bash lockscreen/tests/run.sh` — Expected: PASS.
- [ ] **Step 5: Commit** — `feat(lockscreen): ship the Crate skins and select hero with the rice`

### Task 9: CI

**Files:**
- Create: `.github/workflows/lockscreen.yml`

- [ ] **Step 1**: Workflow on push/PR: `archlinux:latest` container, `pacman -Syu --noconfirm quickshell qt6-declarative qt6-5compat python python-fonttools python-brotli python-pillow`, run `bash lockscreen/tests/run.sh` and `bash lockscreen/tests/package-lock-skins.sh`, plus `python3 -m pytest wallpaper/tests icons/tests tools/director/tests -q`.
- [ ] **Step 2**: Push the branch only when Diego says so; until then validate the workflow syntax with `actionlint` if available (else note it).
- [ ] **Step 3: Commit** — `ci: run the lock screen tests`

### Task 10: Live check with Diego

- [ ] **Step 1**: Build and install into the real session (`package/build.sh`, then the dist's `install.sh`), confirm both skins appear in Settings › Lockscreen.
- [ ] **Step 2**: With Diego at the keyboard, lock with Super+L on `crate/hero`, then `crate/orbit`: wrong password, right password, fingerprint if enrolled, Crate playing and stopped. Capture with `grim` from another session only if Diego asks.
- [ ] **Step 3**: Fix what the live check finds (each fix with its test), then hand back for the PR.
