# Phase 2a: Daily Surfaces (Controls, Notifications, QS Bar) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, as Phase 1) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The surfaces seen every day follow the Crate theme style the way the Hub already
does: the Controls panel (Super+Esc), notification popups and the notification centre,
and the QS bar's own theme (section captions, mono face).

**Architecture:** Same seam as Phase 1, in the Ryoku fork
(`~/Code/Ninja/ryoku`, branch `feat/user-theme-role-overrides`). Each surface reads the
Phase 1 tokens (`pickFill`, `pickEdge`, `pickInk`, `pickInkDim`, `caption`, `mark`,
`navFont`, `trackNav`, `rowWash`, `styled`, `selectFill`), so a theme without a style keeps
the stock look. Live verification through local `ryoku-desktop` packages, as in Phase 1.

**Tech Stack:** QML (Quickshell), Ryoku.Ui `Tokens`, makepkg packages.

**Spec:** `docs/plans/2026-11-12-polish-plan.md` (Fase 2 table; D1, D2, D4); live captures
in `scratchpad/phase2/` (quicksettings.png, notif.png).

## Global Constraints

- A theme without a style renders exactly as before: every change is gated on
  `Tokens.selectFill`, `Tokens.styled`, `Tokens.accentMarks` or `Tokens.labelAccent`, with
  the old value as the other branch.
- D1: a picked tile or card takes `Tokens.pickFill` inside a `Tokens.pickEdge` edge with
  `Tokens.pickInk` text when `!Tokens.selectFill`; segments and chips stay filled.
- D2: section captions use `Tokens.caption`, set in `Tokens.navFont` with `Tokens.trackNav`
  when `Tokens.navCaps`.
- D4: confirm actions are filled; navigation actions (Open, Show, View) are outlined.
- Ryoku commits: `[ryoku] area: summary`, no em-dashes, no AI attribution; hooks run
  by hand (`.githooks/pre-commit`, `commit-msg`).
- No visual change ships without a live capture compared against the stock theme.

## Review Focus

1. Built-in theme (Default): the Controls tiles, notification cards and bar captions look
   as before.
2. A notification with an image, one with actions, a critical one: hairline frame, the
   accent only on the countdown, actions per D4.
3. Wi-Fi off, Bluetooth on: one picked tile, one resting, both legible.
4. Theme switch with a notification on screen restyles it live.
5. The notification centre in the bar renders the same card rules as the popups.

---

### Task 1: Controls panel tiles and captions

**Files:** `ryoku/shell/quickshell/shell/modules/sidebar/ConnectionTile.qml`,
`SidebarToggle.qml`, `SidebarButton.qml`, `PowerProfileControl.qml`, and any other
sidebar file whose active state fills with `Tokens.bone` (grep `Tokens.bone`).

- [ ] **Step 1:** Connected or on: `color` is `Tokens.selectFill ? Tokens.bone : Tokens.pickFill`,
  `border.color` is `Tokens.selectFill ? Tokens.bone : Tokens.pickEdge`, and text and icons use
  `Tokens.selectFill ? Tokens.inkOnBone : Tokens.pickInk` (dim: `pickInkDim`).
- [ ] **Step 2:** Section captions ("Power Profile", "SYSTEM POWER" and their siblings) use
  `Tokens.caption`, plus `navFont` and `trackNav` under `navCaps`.
- [ ] **Step 3:** qmllint the touched files; commit `[ryoku] shell: theme-style picks and captions in the Controls panel`.

### Task 2: Notification cards

**Files:** `ryoku/shell/quickshell/shell/modules/notifications/NotificationCard.qml`,
`NotificationPopups.qml`, and the frame that draws the accent border (find where the
card's outline or the popup frame takes the accent).

- [ ] **Step 1:** Frame: under `Tokens.styled`, a hairline `Tokens.line` edge; the accent
  stays only on the countdown bar and on critical notifications.
- [ ] **Step 2:** App name: `Tokens.caption`, `navFont` caps with `trackNav` under `navCaps`;
  show the app icon (the notification's `appIcon`, else the desktop entry icon through
  `Icons.path`) when the card has no image.
- [ ] **Step 3:** Actions per D4. The default or first confirm-like action stays filled
  (`Tokens.mark` fill, `Tokens.paper` text under `accentMarks`). The rest are outlined
  (`Tokens.mark` edge and text, `Tokens.rowWash` hover). Stock theme: unchanged.
- [ ] **Step 4:** qmllint; commit `[ryoku] shell: notification cards follow the theme style`.

### Task 3: Notification centre and QS bar theme

**Files:** `.../barstyles/qsbar/panels/NotificationPanel.qml`, `.../qsbar/Theme.qml`,
`.../qsbar/modules/PacmanMarker.qml`, `.../qsbar/modules/WorkspaceWidget.qml`.

- [ ] **Step 1:** Make the notification centre use Task 2's card. Where it draws its own,
  apply the same frame, caption and action rules.
- [ ] **Step 2:** In the bar Theme, `sumiHi` (section headers, 74 uses) becomes
  `Tokens.styled ? Tokens.caption : <current>`, and `mono` becomes
  `Tokens.styled ? Tokens.mono : "JetBrainsMono Nerd Font"`.
- [ ] **Step 3:** PacmanMarker and WorkspaceWidget take `mono` from the Theme instead of the
  literal "JetBrainsMono Nerd Font". The CJK and sparkle-glyph faces stay.
- [ ] **Step 4:** qmllint; commit `[ryoku] shell: QS bar captions and mono follow the theme`.

### Task 4: Live verification

- [ ] **Step 1:** Build `ryoku-desktop` pkgrel 9 (same `RYOKU_PKGVER`, via `PKGBUILD.local`);
  keep -8 for rollback. The user installs with `sudo pacman -U`.
- [ ] **Step 2:** Capture the Controls panel (Super+Esc), a test notification with actions,
  a critical one, and the notification centre under Crate and under Default; compare with
  `scratchpad/phase2/quicksettings.png` and `notif.png`.
- [ ] **Step 3:** Record the Review Focus outcomes in the ledger, then run a fresh final
  review of the phase diff.
