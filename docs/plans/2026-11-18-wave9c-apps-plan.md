# Wave 9c: cursor, Thunderbird, Slack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, as for Wave 9). Steps use checkbox (`- [ ]`) syntax.

**Goal:** the Crate cyan cursor, a Crate Thunderbird and the Slack colours, through `crate-for-ryoku`.

**Architecture:** `apps.sh` gains a cursor piece driving `ryoku-hub desktop get/save` with the full document, and the Firefox userChrome code is generalized so Thunderbird reuses it; a Thunderbird `userChrome.css` is built from the tokens; Slack is documentation.

**Tech Stack:** bash, Python 3 (JSON edits), CSS, pytest.

**Spec:** `docs/plans/2026-11-18-wave9c-apps-design.md`

## Global Constraints

- `ryoku-hub desktop save` always receives the full `get` document with only `desktop.cursor.theme` changed.
- The dynamic cursor value is the string `DYNAMIC`; the recolour command is `ryoku-cursor-material-recolor --force --full`.
- Thunderbird profiles come from `$HOME/.thunderbird/profiles.ini`; the record is `$REC/thunderbird-chrome.list`.
- Colours only from `apps/tokens.json`. Tests never touch the real HOME, `ryoku-hub` or Thunderbird.

## Review Focus

- A `get` document with keys the code does not know: all of them come back unchanged after save.
- `ryoku-hub desktop get` failing or returning invalid JSON: nothing is saved, the run continues.
- A cursor picked in the Hub after install: uninstall and a second install leave it.
- Firefox behaviour unchanged after the refactor (the existing tests are the guard).
- A Thunderbird profile with its own `chrome/` (folder or symlink): kept aside and brought back.

---

### Task 1: generalize the Mozilla userChrome code

**Files:** Modify `package/apps.sh` (`firefox_chrome_install/uninstall` → `mozilla_chrome_install LABEL SRC RECORD PROFILE...` / `mozilla_chrome_uninstall LABEL RECORD`, Firefox wrappers call them). No new tests: a refactor under the existing Firefox suite.

- [ ] Refactor; `python3 -m pytest apps/tests -q` stays green with no test changes.
- [ ] Commit `refactor(apps): one userChrome installer for Mozilla apps`.

### Task 2: the Thunderbird sheet and its build

**Files:** Create `apps/thunderbird/chrome/userChrome.css`; Modify `apps/build.py` (`build_thunderbird(out) -> str`); Test `test_thunderbird_chrome_is_crate` (tokens only, `border-radius: 6px`, the accent present, the canvas on the main surfaces).

- [ ] RED → write the sheet → GREEN. Commit `feat(apps): a Crate userChrome for Thunderbird`.

### Task 3: Thunderbird install, status, uninstall

**Files:** Modify `package/apps.sh` (`thunderbird_present`, `thunderbird_profiles` reading `~/.thunderbird/profiles.ini` with Firefox's picking, `--no-thunderbird`, status line); Tests: install into a profile without `chrome/` adds the sheet and the pref, uninstall takes both back; an existing `chrome/` symlink comes back; edited sheet kept aside; no profile → one line; `--no-thunderbird`.

- [ ] RED → implement → GREEN. Commit `feat(apps): install, report and remove the Thunderbird look`.

### Task 4: the cursor piece

**Files:** Modify `package/apps.sh` (`cursor_install`, `cursor_uninstall`, status, `--no-cursor`; record `$REC/cursor.theme`); Tests with a stub `ryoku-hub` keeping the document in a file and a stub recolour that logs its call: install sets `DYNAMIC`, keeps `wm` and every other key, calls the recolour; uninstall restores `Bibata-Modern-Ice`; a theme picked since survives uninstall and a second install; invalid `get` → nothing saved; no `ryoku-hub` → skipped quietly; `--no-cursor`.

- [ ] RED → implement → GREEN. Commit `feat(apps): the Crate cyan cursor through Ryoku's dynamic Bibata`.

### Task 5: flags, Slack and docs

**Files:** `package/install.sh` (`--no-thunderbird|--no-cursor`), READMEs, `docs/app-themes.md` (Thunderbird and cursor rows, the Slack section), the passthrough test.

- [ ] RED → GREEN with the full CI suite and `package-apps.sh`. Commit `feat(install): --no-thunderbird and --no-cursor, and the Slack colours`.

### Task 6: live review

- [ ] Back up `desktop.json` and the Thunderbird profile's `user.js`; install from the branch; capture Thunderbird (folder pane, thread list, a message) and the pointer; iterate the sheet with Diego.
