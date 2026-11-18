# Wave 9b: GTK apps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Diego chose inline execution for Wave 9). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Crate's CSS and code colours in GTK apps, through a generic `user.css` include in the Ryoku fork.

**Architecture:** The fork's GTK matugen templates import `user.css` and the render creates it empty when missing; crate-for-ryoku ships `apps/gtk/crate.css` and `apps/gtksourceview/crate.xml` and wires them in `package/apps.sh` with the Wave 9a patterns (records under `$REC`, checksums, never over the user's own content).

**Tech Stack:** Go (Ryoku fork), CSS, GtkSourceView 5 XML, bash, pytest.

**Spec:** `docs/plans/2026-11-17-wave9b-gtk-design.md`

## Global Constraints

- Colours only from `apps/tokens.json` (rgba tokens as `rgba(...)` in CSS; in the XML as `#rrggbbaa` or solid over canvas).
- The user line in `user.css` is exactly `@import url("crate.css"); /* crate-for-ryoku */`.
- GtkSourceView scheme `id="crate"`, installed to `~/.local/share/gtksourceview-5/styles/crate.xml`.
- Fork commits: `[ryoku] shell: ...`, a `Note:` trailer, CHANGELOG entry; run `.githooks/pre-commit` and `commit-msg` by hand.
- Tests never touch the real HOME or the real gsettings (stub `gsettings` with a state file).

## Review Focus

- A `user.css` with the user's own rules, before and after install/uninstall: their lines stay byte for byte.
- `user.css` missing on a stock Ryoku (no import in `gtk.css`): status says the CSS is not loaded; nothing breaks.
- Text Editor scheme switched by the user after install: uninstall leaves their pick.
- install twice: one import line, one gsettings record.
- An edited `crate.css` or `crate.xml`: uninstall keeps it.

---

### Task 1 (fork): GTK user include

**Files:** Modify `ryoku/shell/matugen/templates/gtk4-colors.css`, `gtk3-colors.css`, `ryoku/shell/ipc/matugen.go`; Test `ryoku/shell/ipc/gtk_user_css_test.go`; CHANGELOG `ryoku/shell/CHANGELOG.md`.

**Interfaces:** Produces `ensureGtkUserCSS(cfgBase string)` (creates `cfgBase/gtk-{3,4}.0/user.css` empty when missing), called from `matugenRenderTemplates` after the app suite renders.

- [ ] Tests: `TestGtkTemplatesImportUserCSS` (both shipped templates end with `@import url("user.css");`), `TestEnsureGtkUserCSSCreatesMissing`, `TestEnsureGtkUserCSSKeepsExisting` (bytes unchanged).
- [ ] Run `go test ./shell/ipc -run GtkUser` from `ryoku/` → FAIL; implement; → PASS; then the package's whole suite.
- [ ] Commit `[ryoku] shell: let GTK load a user.css that survives palette renders`.

### Task 2: `apps/gtk/crate.css` and its build

**Files:** Create `apps/gtk/crate.css`; Modify `apps/build.py` (`build_gtk(out) -> str` writes `<out>/gtk/crate.css`); Test `apps/tests/test_apps.py`.

- [ ] Test `test_gtk_css_is_crate`: every `#rrggbb` and `rgba(...)` in the file is a token; it sets `--dialog-bg-color: #111218`, `--thumbnail-bg-color: #111218`, `--headerbar-border-color: rgba(241, 245, 249, 0.1)` and contains `border-radius: 6px`.
- [ ] RED → write the file per the spec → GREEN (whole `apps/tests`).
- [ ] Commit `feat(apps): Crate's corners and hairlines for GTK apps`.

### Task 3: `apps/gtksourceview/crate.xml` and its build

**Files:** Create `apps/gtksourceview/crate.xml`; Modify `apps/build.py` (`build_gtksourceview(out) -> str`); Test `apps/tests/test_apps.py`.

- [ ] Test `test_gtksourceview_scheme_is_crate`: parses with `xml.etree`; root `style-scheme` `id="crate"`; metadata property `variant` is `dark`; `def:keyword` foreground accent, `def:string` accent_hi, `def:number` warning, `def:comment` faint and `italic="true"`; every colour is a token or token over canvas.
- [ ] RED → write the scheme (styles listed in the spec) → GREEN; also load it with `GtkSource.StyleSchemeManager` from a temp search path as a throwaway check.
- [ ] Commit `feat(apps): a Crate scheme for GtkSourceView`.

### Task 4: apps.sh GTK piece

**Files:** Modify `package/apps.sh`; Test `apps/tests/test_apps.py`.

**Interfaces:** Consumes `$APPS/gtk/crate.css`. Records `$REC/gtk.list` (`dir<TAB>sha<TAB>created_user_css`). Status label `GTK`.

- [ ] Tests (fake HOME): fresh install creates both `crate.css` and `user.css` with the line, uninstall removes both; an existing `user.css` with the user's rules keeps them through install and uninstall; second install adds no second line; edited `crate.css` survives uninstall; `--no-gtk`; status says "does not load user.css" when `gtk.css` lacks the import and `Crate CSS` when it has it.
- [ ] RED → implement → GREEN.
- [ ] Commit `feat(apps): install, report and remove Crate's GTK CSS`.

### Task 5: apps.sh Text Editor piece

**Files:** Modify `package/apps.sh`; Test `apps/tests/test_apps.py` (a `gsettings` stub storing the key in a file).

**Interfaces:** Consumes `$APPS/gtksourceview/crate.xml`. Records `$REC/texteditor.scheme` (previous value) and `$REC/gtksourceview.sha`. Status label `Text Editor`.

- [ ] Tests: install copies the scheme and sets `crate`, uninstall restores `'Adwaita'` and removes the file; a scheme picked since stays and a second install does not re-select; edited `crate.xml` survives; no `gnome-text-editor` → scheme file still installed, nothing selected; `--no-gtksourceview`.
- [ ] RED → implement → GREEN.
- [ ] Commit `feat(apps): install, report and remove the Crate GtkSourceView scheme`.

### Task 6: flags and docs

**Files:** `package/install.sh` (`--no-gtk|--no-gtksourceview` in the `APP_OPTS` case and help), `package/README.md`, `README.md`, `docs/app-themes.md`, the passthrough test.

- [ ] Update the passthrough test (RED) → flags and docs → full CI suite and `package-apps.sh` GREEN.
- [ ] Commit `feat(install): --no-gtk and --no-gtksourceview, and their docs`.

### Task 7: live review

- [ ] Build the fork packages from `crate/wave9b-gtk-user-css` (`build-ryoku.sh --ref ...`), hand Diego the `sudo pacman -U`, confirm `gtk.css` ends with the import after a re-render.
- [ ] Install the apps from the branch (`CRATE_APPS_DIR=<build> bash package/apps.sh install --no-obsidian --no-firefox`), capture Nautilus, Text Editor (Markdown, Python) and Loupe, review with Diego.
