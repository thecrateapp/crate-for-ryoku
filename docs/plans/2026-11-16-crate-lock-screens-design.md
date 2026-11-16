# Crate lock screens — design

Date: 2026-11-16. Status: approved in conversation (sections 1–4), pending review of this document.
Decision D6 of `2026-11-12-polish-plan.md` asks for a Crate lock screen inside Crate for Ryoku.
This spec covers two skins, both selectable.

## Goal

Ryoku's lock screen today is qylock's `clockwork/orbital`. Crate for Ryoku ships two Crate
lock-screen skins so a Crate desktop locks into Crate's look:

- `crate/hero`: new layout after the cratemusic.app hero (D6 as written). Default for the rice.
- `crate/orbit`: orbital's structure (minute dial, right-aligned sign-in) dressed in Crate.

Success: both skins appear in Ryoku Settings › Lockscreen, unlock reliably with password,
fingerprint and security key, look right in the session lock and in SDDM, and can be developed
and reviewed without locking the session.

## Background (how qylock works)

- `ryoku-shell lock` → `ryoku-qylock-lock` → `lock.sh` → `quickshell -p lock_shell.qml`, which
  holds the `WlSessionLock` and loads `$QS_THEME_PATH/Main.qml` per screen. The FingerprintScan
  overlay is drawn by `lock_shell.qml` above every skin.
- A skin is any folder with `Main.qml` under `~/.local/share/qylock/themes/<group>/<name>/`
  (`ryoku/hub/backend/lock.go`). The active skin is `~/.config/qylock/theme`. A rice selects one
  with `assets.lock` (`rice.go` `setLockSkinIn`).
- A skin sees the SDDM shim API (`SddmShim.qml`): `sddm.login()`, `loginFailed`,
  `loginSucceeded`, `fingerprintState`, `keyState`, `keyPrompts`, `reboot`, `powerOff`,
  `suspend`, `userModel`, plus `config` (theme.conf + `clock24h`). It can import
  `Ryoku.Ui.Singletons` (Tokens) in the session lock.
- The same skin can serve as the SDDM greeter (`install-greeter-theme` copies the folder). There
  is no user `$HOME`, no Tokens customisation and no `Quickshell.Services.Mpris` there.
- The Hub's Preview button really locks the session. Ryoku's `tests/lock-*.sh` load a skin
  offscreen in a plain `ShellRoot` with a fake `sddm`.
- `lock_shell.qml:183` delays the unlock only for skins whose name contains "clockwork"; ours
  exit after 100 ms like any other.

## Structure

```
lockscreen/
  crate/
    common/            shared QML: CratePalette, Fonts, PasswordField, NowPlaying,
                       PowerRow, ErrorLine, Background; fonts/; backgrounds/
    hero/              Main.qml, theme.conf, metadata.desktop, preview.gif, i18n/
    orbit/             Main.qml, theme.conf, metadata.desktop, preview.gif, i18n/
  preview.sh           windowed preview and offscreen shots
  tests/               lock-crate-*.sh + .qml (PASS/FAIL harness)
```

- Source skins import `../common`. `package/build.sh` vendors `common/` (QML, fonts,
  backgrounds) into each built skin so the installed folder is self-contained; SDDM copies only
  the skin folder.
- `CratePalette` holds Crate's tokens as constants (canvas #0a0a0f, text #f1f5f9, secondary
  0.62, faint 0.42, hairline rgba(241,245,249,0.1), cyan #06b6d4 / #67e8f9, danger #ef4444,
  radius 6). In the session lock it prefers `Tokens` values when `Tokens.controlsCrate` is on;
  otherwise (SDDM, stock Ryoku) the constants apply.
- Fonts: Bricolage Grotesque (display, 800) and JetBrains Mono (labels, uppercase, 0.12–0.14em
  tracking), loaded from the skin's `fonts/` with `FontLoader`.
- Backgrounds: Groove and Sheen rendered by `wallpaper/groove.py` and `sheen.py` at 3840x2400,
  shipped as WebP, with a dark veil for legibility.

### theme.conf options (per skin)

| Key | Values | Default |
|---|---|---|
| `showNowPlaying` | `true` / `false` | `true` |
| `background` | `groove` / `sheen` | `groove` |

There is no Hub UI for skin options; they are edited by hand for now.

## Behaviour common to both skins

- **Password**: focused on show; Enter calls `sddm.login(user, password, session)`. While PAM
  works the field is disabled and the hint reads "Checking". On `loginFailed` the underline and
  hint turn danger red with PAM's message, the field clears and nudges sideways once (no nudge
  under reduced motion).
- **Fingerprint and security key**: qylock draws the scan overlay; the skin only changes its hint
  ("or touch the reader"; cyan on success, red on failure). Security-key prompts replace the hint
  and the field takes the PIN when `keyState` asks for it.
- **User**: shows the last user. With several users, clicking the name switches among them inside
  the skin (no popups exist in a session lock).
- **Power**: Suspend, Reboot, Shut down as mono links with Crate's hover underline; they act
  directly, as in orbital.
- **Now playing**: only in the session lock and only when `showNowPlaying` is true. Reads Crate
  over MPRIS (`org.mpris.MediaPlayer2.crate`): cover, title, artist, progress. No transport
  controls. Hidden when Crate is not playing. Never instantiated in SDDM.
- **Clock and text**: Ryoku's global 12/24 h setting; strings through qylock's i18n with English
  as the base, as orbital does.
- **Caps Lock**: not shown (the shim reports a constant false).
- **Motion**: only real transitions; everything static under reduced motion.
- **Monitors**: the full skin on every screen, as qylock does today.

## `crate/hero`

- Top left: "LOCKED · <host>" (mono, faint, cyan separator). Top right: the power row.
- Left: date in mono cyan ("MONDAY · 16 NOV 2026", day in cyan, rest secondary) above the clock in
  Bricolage 800 (~300 px at 1200 px height, tight tracking). A digit slides briefly when it changes.
- Bottom left: now playing block — hairline top rule, 72 px cover (6 px radius), "NOW PLAYING IN
  CRATE" label, title (Bricolage 700), artist (secondary), a 2 px progress line in cyan.
- Bottom right: user name (Bricolage 700) with `user@host` in mono below; "PASSWORD" label; the
  field as a single underline (cyan when focused, red on error) with mono bullets and a cyan caret;
  hint line below.

## `crate/orbit`

- Orbital's composition: the hour (Bricolage 800) inside a minute dial that bleeds off the left
  edge and turns with the real minutes; minutes in mono cyan; the date (mono) with the weekday in
  Bricolage uppercase; power row top right with hairline separators.
- Sign-in bottom right, right-aligned: user name (mono, spaced), password bullets, an "Unlock"
  action with Crate's cyan mark, error line in red ("ACCESS DENIED" + PAM message).
- Now playing as a single discreet mono line bottom left ("NOW PLAYING · Artist — Title").
- No windup animation and no ring "blast" from orbital.

## Preview and tests

- `lockscreen/preview.sh <crate/hero|crate/orbit> [state] [--shot out.png]` builds the same
  temporary environment as Ryoku's lock tests (fake `sddm`, fake MPRIS player, `Ryoku.Ui`
  imports) and opens the skin in a plain window, never a `WlSessionLock`. States: idle, typing,
  checking, error, fingerprint (scanning/success/fail), key (pin/touch), no-music, sddm.
  `--shot` renders offscreen to a PNG; build uses it for `preview.gif`.
- Tests (`lockscreen/tests/lock-crate-*.sh`, PASS/FAIL format) per skin: loads in lock and SDDM
  modes (no MPRIS and no now-playing in SDDM); Enter with text calls `sddm.login` with user and
  password; `loginFailed` shows the error and clears the field; no player hides now playing;
  12/24 h follows the global setting; theme.conf options apply. They run locally next to the
  repo's other tests; crate-for-ryoku has no CI yet, so the implementation plan adds a GitHub
  workflow that runs them (Quickshell offscreen on an Arch container).

## Packaging and the rice

- `package/build.sh` vendors `common/` into `hero/` and `orbit/` and renders `preview.gif`.
- `crate-for-ryoku install` copies both skins to `~/.local/share/qylock/themes/crate/`;
  `uninstall` removes them and, if the active skin was ours, restores the previous one (recorded
  in the installer state; fallback `clockwork/orbital`).
- `rice/crate/rice.json` declares `"assets": { "lock": "crate/hero" }`.
- SDDM is left alone; users can install a skin as greeter with Ryoku's `install-greeter-theme`.
- NOTICE lists the fonts (SIL OFL) and the backgrounds.

## Out of scope

- Transport controls on the lock screen; Caps Lock detection; a Hub UI for skin options;
  changing qylock or Ryoku itself; installing the SDDM greeter automatically.
