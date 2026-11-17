# Wave 9a: editor and terminal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zed and lazygit in Crate's look, installed, reported and removed by `crate-for-ryoku` like the Obsidian and Firefox themes.

**Architecture:** Two static theme files under `apps/` (copied into the dist by `apps/build.py`), a small JSONC editor for Zed's `settings.json` (`package/zed_settings.py`), and Zed/lazygit sections in `package/apps.sh` that follow the existing Obsidian pattern (record under `$REC`, checksum before removing, never over the user's own file).

**Tech Stack:** bash (apps.sh), Python 3 stdlib (build.py, zed_settings.py), pytest.

**Spec:** `docs/plans/2026-11-17-wave9a-editor-terminal-design.md`

## Global Constraints

- Every colour comes from `apps/tokens.json` or from `theme/crate/scheme.json` `dark.terminal` (the kitty palette). rgba tokens are written as `#rrggbbaa` in Zed; in lazygit they are resolved to solid hex over `canvas` (`#0a0a0f`).
- Zed theme: schema `https://zed.dev/schema/themes/v0.2.0.json`, family `"Crate"`, one theme `"Crate"`, `"appearance": "dark"`.
- Zed settings: only `theme.dark` (object form) or `theme` (string form) changes; `mode` and `light` untouched; comments and formatting preserved; writes via temp file + `os.replace`.
- lazygit file starts with the line `# crate-for-ryoku: lazygit`; written only if `config.yml` is absent, empty or starts with that line.
- Nothing runs as root; tests never touch the real HOME (use the `home` fixture in `apps/tests/test_apps.py`).
- Run tests with `python3 -m pytest apps/tests -q` from the repo root.

## Review Focus

- A Zed `settings.json` whose `"theme"` text appears inside a comment or a string before the real key: the editor must change the real top-level key only.
- `crate-for-ryoku install` run twice, with the user switching Zed to another theme in between: the second run must not re-select Crate.
- Uninstall after the user edited the installed `themes/crate.json` or the Crate lazygit `config.yml` (removed the marker line): their file stays.
- A Zed `settings.json` with trailing commas or `/* */` comments (valid for Zed): select and restore still work.
- Zed installed but never started (no `~/.config/zed`): install creates `settings.json` and uninstall removes it again.

---

### Task 1: Zed Crate theme and its build

**Files:**
- Create: `apps/zed/crate.json`
- Modify: `apps/build.py` (add `build_zed(out) -> str`, call it in `main`)
- Test: `apps/tests/test_apps.py`

**Interfaces:**
- Produces: `build.build_zed(out: str) -> str` returning `<out>/zed/crate.json`; the dist file `apps/zed/crate.json` (installed by Task 4 from `$APPS/zed/crate.json`); test helpers `crate_bases()` and `colours(node)` in `test_apps.py`.

- [ ] **Step 1: Write the failing tests** (append to the built-themes section)

```python
SCHEME = json.load(open(os.path.join(ROOT, "theme/crate/scheme.json")))["dark"]

def crate_bases():
    """Every #rrggbb a Crate app theme may use."""
    bases = {v.lower() for v in TOKENS.values() if isinstance(v, str) and v.startswith("#")}
    for v in TOKENS.values():
        if isinstance(v, str) and v.startswith("rgba("):
            r, g, b = (int(x) for x in v[5:-1].split(",")[:3])
            bases.add("#%02x%02x%02x" % (r, g, b))
    t = SCHEME["terminal"]
    bases |= {v.lower() for k, v in t.items() if isinstance(v, str)}
    bases |= {v.lower() for group in ("normal", "bright") for v in t[group].values()}
    return bases

def colours(node):
    if isinstance(node, dict):
        for v in node.values(): yield from colours(v)
    elif isinstance(node, list):
        for v in node: yield from colours(v)
    elif isinstance(node, str) and re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", node):
        yield node.lower()

def test_zed_theme_is_one_dark_crate_theme(out):
    doc = json.load(open(out / "zed/crate.json"))
    assert doc["$schema"] == "https://zed.dev/schema/themes/v0.2.0.json"
    assert doc["name"] == "Crate" and len(doc["themes"]) == 1
    theme = doc["themes"][0]
    assert theme["name"] == "Crate" and theme["appearance"] == "dark"
    s = theme["style"]
    assert s["editor.background"].lower() == TOKENS["canvas"]
    assert s["border.focused"].lower() == TOKENS["accent"]
    assert s["border"].lower() == "#f1f5f91a"          # hairline: text at 0.1

def test_zed_theme_uses_only_crate_colours(out):
    doc = json.load(open(out / "zed/crate.json"))
    bad = sorted({c for c in colours(doc) if c[:7] not in crate_bases()})
    assert bad == []

def test_zed_terminal_matches_kitty(out):
    s = json.load(open(out / "zed/crate.json"))["themes"][0]["style"]
    t = SCHEME["terminal"]
    for name, hexv in t["normal"].items():
        assert s[f"terminal.ansi.{name}"].lower() == hexv
    for name, hexv in t["bright"].items():
        assert s[f"terminal.ansi.bright_{name}"].lower() == hexv
    assert s["terminal.background"].lower() == t["background"]
```

- [ ] **Step 2: Run them to verify they fail**

Run: `python3 -m pytest apps/tests -q -k zed`
Expected: FAIL (`zed/crate.json` not in the build output).

- [ ] **Step 3: Write `apps/zed/crate.json` and `build_zed`**

Use the key inventory of Ryoku's matugen template `~/.config/matugen/templates/zed.json` (the same v0.2.0 keys, ~135 style keys plus `players` and `syntax`) so no key falls back to Zed's default; fill every value per the spec's "Zed theme" section. Alpha suffixes: `text_secondary` `#f1f5f99e`, `text_faint` `#f1f5f96b`, `hairline` `#f1f5f91a`; editor selection `#06b6d433`; warning/danger backgrounds at `1a`. Syntax: `keyword`, `function` accent; `type`, `string` accent_hi; `number`, `constant`, `boolean` warning; `comment` text_faint with `"font_style": "italic"`; `variable`, `property` text; `punctuation*` text_secondary. `build_zed` copies the file to `<out>/zed/crate.json` byte for byte (keeps the build reproducible) and `main` prints `zed      <path>`.

- [ ] **Step 4: Run the tests**

Run: `python3 -m pytest apps/tests -q`
Expected: all pass, including `test_builds_are_reproducible`.

- [ ] **Step 5: Commit**

```bash
git add apps/zed/crate.json apps/build.py apps/tests/test_apps.py
git commit -m "feat(apps): a Crate theme for Zed"
```

### Task 2: lazygit Crate theme and its build

**Files:**
- Create: `apps/lazygit/config.yml`
- Modify: `apps/build.py` (add `build_lazygit(out) -> str`, call it in `main`)
- Test: `apps/tests/test_apps.py`

**Interfaces:**
- Consumes: `crate_bases()` helper from Task 1.
- Produces: `build.build_lazygit(out: str) -> str` returning `<out>/lazygit/config.yml`; marker line `# crate-for-ryoku: lazygit` (first line).

- [ ] **Step 1: Write the failing test**

```python
def over_canvas(token):
    r, g, b, a = (float(x) for x in TOKENS[token][5:-1].split(","))
    c = rgb(TOKENS["canvas"])
    return "#%02x%02x%02x" % tuple(round(a * v + (1 - a) * w) for v, w in zip((r, g, b), c))

def test_lazygit_theme_is_marked_and_crate(out):
    text = (out / "lazygit/config.yml").read_text()
    assert text.splitlines()[0] == "# crate-for-ryoku: lazygit"
    assert "activeBorderColor:" in text and TOKENS["accent"] in text
    assert over_canvas("hairline") in text          # inactive border, solid
    found = {c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}\b", text)}
    allowed = crate_bases() | {over_canvas(t) for t in ("hairline", "text_secondary", "text_faint")}
    assert found and found <= allowed
```

- [ ] **Step 2: Run to verify it fails**

Run: `python3 -m pytest apps/tests -q -k lazygit`
Expected: FAIL (file missing from the build).

- [ ] **Step 3: Write `apps/lazygit/config.yml` and `build_lazygit`**

Only `gui.theme` (values are lists, lazygit style): `activeBorderColor: ["#06b6d4", bold]`, `inactiveBorderColor: [<hairline over canvas>]`, `searchingActiveBorderColor: ["#fbbf24", bold]`, `optionsTextColor: ["#06b6d4"]`, `selectedLineBgColor: ["#0f1016"]`, `inactiveViewSelectedLineBgColor: ["#15161d"]`, `cherryPickedCommitFgColor: ["#06b6d4"]`, `cherryPickedCommitBgColor: ["#15161d"]`, `markedBaseCommitFgColor: ["#67e8f9"]`, `markedBaseCommitBgColor: ["#15161d"]`, `unstagedChangesColor: ["#ef4444"]`, `defaultFgColor: ["#f1f5f9"]`. Compute the hairline-over-canvas hex with `over_canvas` once and write it literally. `build_lazygit` copies the file byte for byte.

- [ ] **Step 4: Run the tests**

Run: `python3 -m pytest apps/tests -q`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/lazygit/config.yml apps/build.py apps/tests/test_apps.py
git commit -m "feat(apps): a Crate theme for lazygit"
```

### Task 3: Zed settings editor

**Files:**
- Create: `package/zed_settings.py`
- Modify: `package/build.sh` (copy it beside `apps.sh` on the `cp` line, `python3 -m py_compile` it next to the `bash -n` checks)
- Test: `apps/tests/test_zed_settings.py`

**Interfaces:**
- Produces (Python): `select(path: str, theme: str) -> tuple[str, str]` returning `(mode, previous)` where mode is `"dark"`, `"string"`, `"added"` or `"created"` and previous is the JSON text of the replaced value (`json.dumps` form, one line) or `"-"`; raises `ValueError` on text it cannot parse, writing nothing. `restore(path: str, theme: str, mode: str, previous: str) -> bool` (True when it put the old state back, False when the current value is not `theme` any more). `current(path: str) -> str` (the dark theme name in effect, `""` when unset or unreadable).
- Produces (CLI, used by Task 4): `python3 zed_settings.py select PATH THEME` prints `mode<TAB>previous`, exit 0; exit 3 on invalid JSONC. `python3 zed_settings.py restore PATH THEME MODE PREVIOUS` prints `restored` or `kept`. `python3 zed_settings.py current PATH` prints the name.

- [ ] **Step 1: Write the failing tests** (`apps/tests/test_zed_settings.py`; `ZS = <repo>/package/zed_settings.py`, imported as `zs` via `sys.path`)

```python
DEFAULT = '// Zed settings\n//\n// see docs\n{\n  "ui_font_size": 16,\n  "theme": {\n    "mode": "system",\n    "light": "One Light",\n    "dark": "One Dark"\n  }\n}\n'

def test_select_changes_only_the_dark_slot(tmp_path):
    p = tmp_path / "settings.json"; p.write_text(DEFAULT)
    assert zs.select(str(p), "Crate") == ("dark", '"One Dark"')
    assert p.read_text() == DEFAULT.replace('"dark": "One Dark"', '"dark": "Crate"')

def test_restore_puts_the_old_dark_back(tmp_path):
    p = tmp_path / "settings.json"; p.write_text(DEFAULT)
    mode, prev = zs.select(str(p), "Crate")
    assert zs.restore(str(p), "Crate", mode, prev) is True
    assert p.read_text() == DEFAULT

def test_restore_keeps_a_theme_picked_since(tmp_path):
    p = tmp_path / "settings.json"; p.write_text(DEFAULT)
    mode, prev = zs.select(str(p), "Crate")
    p.write_text(p.read_text().replace('"Crate"', '"Gruvbox"'))
    assert zs.restore(str(p), "Crate", mode, prev) is False
    assert '"Gruvbox"' in p.read_text()

def test_string_theme_with_trailing_comma(tmp_path):
    p = tmp_path / "settings.json"; p.write_text('{ "theme": "Ayu Dark", }')
    assert zs.select(str(p), "Crate") == ("string", '"Ayu Dark"')
    assert zs.current(str(p)) == "Crate"
    zs.restore(str(p), "Crate", "string", '"Ayu Dark"')
    assert p.read_text() == '{ "theme": "Ayu Dark", }'

def test_missing_key_is_added_and_removed(tmp_path):
    src = '{\n  /* mine */ "vim_mode": true\n}\n'
    p = tmp_path / "settings.json"; p.write_text(src)
    mode, prev = zs.select(str(p), "Crate")
    assert (mode, prev) == ("added", "-") and zs.current(str(p)) == "Crate"
    zs.restore(str(p), "Crate", mode, prev)
    assert p.read_text() == src

def test_missing_file_is_created_and_removed(tmp_path):
    p = tmp_path / "zed/settings.json"
    assert zs.select(str(p), "Crate") == ("created", "-")
    assert zs.current(str(p)) == "Crate"
    assert zs.restore(str(p), "Crate", "created", "-") is True
    assert not p.exists()

def test_theme_words_in_comments_and_strings_are_not_the_key(tmp_path):
    src = '// "theme": "x"\n{ "note": "\\"theme\\": nope", "theme": {"dark": "One Dark"} }'
    p = tmp_path / "settings.json"; p.write_text(src)
    zs.select(str(p), "Crate")
    assert p.read_text() == src.replace('"dark": "One Dark"', '"dark": "Crate"')

def test_invalid_jsonc_is_left_untouched(tmp_path):
    p = tmp_path / "settings.json"; p.write_text('{ "theme": ')
    with pytest.raises(ValueError):
        zs.select(str(p), "Crate")
    assert p.read_text() == '{ "theme": '

def test_cli_select_prints_mode_and_previous(tmp_path):
    p = tmp_path / "settings.json"; p.write_text(DEFAULT)
    r = subprocess.run([sys.executable, ZS, "select", str(p), "Crate"], capture_output=True, text=True)
    assert r.returncode == 0 and r.stdout == 'dark\t"One Dark"\n'
```

- [ ] **Step 2: Run to verify they fail**

Run: `python3 -m pytest apps/tests/test_zed_settings.py -q`
Expected: FAIL (module missing).

- [ ] **Step 3: Implement `package/zed_settings.py`**

A scanner over the text that tracks depth and skips `"..."` strings (with `\` escapes), `//` line comments and `/* */` comments; at depth 1 a string token `"theme"` followed by `:` starts the value. The value span is a string token or a `{...}` (match braces with the same skipping). In an object value, find the depth-1 key `"dark"` and its string token span (no `"dark"` key: insert `"dark": "<theme>"` and treat it as mode `"added"` inside the object, restored by removing that insertion). Edits are slices of the original text, so everything else stays byte-identical. Mode "added" (no top-level key) inserts `"theme": {"dark": "<theme>"}` after the opening `{` of the top-level object, with a comma when the object is not empty, and `restore` removes exactly that inserted text. Mode "created" writes `{"theme": {"mode": "system", "light": "One Light", "dark": "<theme>"}}\n` (creating the parent folder) and `restore` deletes the file only while it is exactly that text. A scan that does not end balanced raises `ValueError` before anything is written. Write with temp file + `os.replace`. `main(argv)` maps the three commands; `ValueError` → exit 3.

- [ ] **Step 4: Run the tests**

Run: `python3 -m pytest apps/tests/test_zed_settings.py -q`
Expected: all pass.

- [ ] **Step 5: Ship it beside apps.sh**

In `package/build.sh` add `"$SRC/package/zed_settings.py"` to the `cp` that copies `apps.sh`, and `python3 -m py_compile "$OUT/zed_settings.py"` after the `bash -n` checks. Run the package build and confirm `zed_settings.py` sits beside `apps.sh` in the output.

- [ ] **Step 6: Commit**

```bash
git add package/zed_settings.py package/build.sh apps/tests/test_zed_settings.py
git commit -m "feat(package): edit Zed's settings.json without touching anything else"
```

### Task 4: apps.sh installs, reports and removes the Zed theme

**Files:**
- Modify: `package/apps.sh` (new `zed_*` functions, `ZED` flag, `--no-zed`, status line, usage text, header comment)
- Test: `apps/tests/test_apps.py`

**Interfaces:**
- Consumes: Task 1 dist file `$APPS/zed/crate.json`; Task 3 CLI `python3 "$HERE/zed_settings.py" select|restore|current`.
- Produces: record `$REC/zed-settings.list` (`file<TAB>mode<TAB>previous`), `$REC/zed-theme.sha`; status line `Zed` with `installed; Crate selected`, `installed; Crate not selected` or `not installed`.

- [ ] **Step 1: Write the failing tests** (fake HOME via the `home` fixture; `stub(run, "zed")` makes Zed present; add `"python3"` to `TOOLS` if it is not there)

```python
ZED_DEFAULT = '// Zed\n{\n  "theme": {\n    "mode": "system",\n    "light": "One Light",\n    "dark": "One Dark"\n  }\n}\n'

def test_zed_install_selects_crate_and_uninstall_puts_one_dark_back(home, out):
    h, run = home; stub(run, "zed")
    s = h / ".config/zed/settings.json"; s.parent.mkdir(parents=True); s.write_text(ZED_DEFAULT)
    run("install")
    assert (h / ".config/zed/themes/crate.json").read_bytes() == (out / "zed/crate.json").read_bytes()
    assert '"dark": "Crate"' in s.read_text()
    assert re.search(r"Zed +installed; Crate selected", run("status"))
    run("uninstall")
    assert s.read_text() == ZED_DEFAULT
    assert not (h / ".config/zed/themes/crate.json").exists()

def test_zed_second_install_keeps_a_theme_picked_since(home):
    h, run = home; stub(run, "zed")
    s = h / ".config/zed/settings.json"; s.parent.mkdir(parents=True); s.write_text(ZED_DEFAULT)
    run("install"); s.write_text(s.read_text().replace('"Crate"', '"Gruvbox"'))
    log = run("install")
    assert '"Gruvbox"' in s.read_text() and "Gruvbox" in log
    assert re.search(r"Zed +installed; Crate not selected", run("status"))

def test_zed_never_started_gets_a_settings_file_and_loses_it_again(home):
    h, run = home; stub(run, "zed")
    run("install")
    assert '"dark": "Crate"' in (h / ".config/zed/settings.json").read_text()
    run("uninstall")
    assert not (h / ".config/zed/settings.json").exists()

def test_zed_uninstall_keeps_an_edited_theme_file(home):
    h, run = home; stub(run, "zed")
    run("install")
    t = h / ".config/zed/themes/crate.json"; t.write_text(t.read_text() + "\n")
    run("uninstall")
    assert t.exists()

def test_no_zed_leaves_zed_alone(home):
    h, run = home; stub(run, "zed")
    run("install", "--no-zed")
    assert not (h / ".config/zed").exists()

def test_zed_not_installed_is_reported(home):
    h, run = home
    assert re.search(r"Zed +not installed", run("status"))
```

- [ ] **Step 2: Run to verify they fail**

Run: `python3 -m pytest apps/tests -q -k zed`
Expected: the new install tests FAIL.

- [ ] **Step 3: Implement the Zed section in `package/apps.sh`**

Mirror `obsidian_install`/`obsidian_uninstall`: `zed_present` (`command -v zed`, `$HOME/.local/zed.app`, or `$CFG/zed`); `zed_install` (copy theme, record its sha, `select` once guarded by the record; exit 3 → warn "Zed: $file is not valid JSON; Crate is there but not selected"; when a record exists and `current` is not Crate → say "Zed: you use <name> since; left as it is"); `zed_uninstall` (`restore` from the record, remove the theme file only if its sha still matches, clear the records; `--look-only` restores but keeps the file, like Obsidian). Wire `ZED=1`, `--no-zed`, the install/uninstall calls and the status line next to Obsidian's.

- [ ] **Step 4: Run all app tests**

Run: `python3 -m pytest apps/tests -q`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add package/apps.sh apps/tests/test_apps.py
git commit -m "feat(apps): install, report and remove the Zed theme"
```

### Task 5: apps.sh installs, reports and removes the lazygit theme

**Files:**
- Modify: `package/apps.sh` (`lazygit_*` functions, `LAZYGIT` flag, `--no-lazygit`, status line, usage)
- Test: `apps/tests/test_apps.py`

**Interfaces:**
- Consumes: Task 2 dist file `$APPS/lazygit/config.yml` and its marker line.
- Produces: record `$REC/lazygit.state` (`absent` or `empty`: what was there before); status line `lazygit` with `Crate theme`, `your own config.yml` or `not installed`.

- [ ] **Step 1: Write the failing tests**

```python
def test_lazygit_empty_config_gets_crate_and_goes_back_to_empty(home, out):
    h, run = home; stub(run, "lazygit")
    c = h / ".config/lazygit/config.yml"; c.parent.mkdir(parents=True); c.write_text("")
    run("install")
    assert c.read_bytes() == (out / "lazygit/config.yml").read_bytes()
    assert re.search(r"lazygit +Crate theme", run("status"))
    run("uninstall")
    assert c.exists() and c.read_text() == ""

def test_lazygit_without_config_gets_one_and_loses_it(home):
    h, run = home; stub(run, "lazygit")
    run("install"); run("uninstall")
    assert not (h / ".config/lazygit/config.yml").exists()

def test_lazygit_own_config_is_left_alone(home):
    h, run = home; stub(run, "lazygit")
    c = h / ".config/lazygit/config.yml"; c.parent.mkdir(parents=True); c.write_text("gui:\n  nerdFontsVersion: 3\n")
    log = run("install")
    assert c.read_text() == "gui:\n  nerdFontsVersion: 3\n" and "your own config.yml" in log
    assert re.search(r"lazygit +your own config.yml", run("status"))

def test_lazygit_config_edited_without_the_marker_survives_uninstall(home):
    h, run = home; stub(run, "lazygit")
    run("install")
    c = h / ".config/lazygit/config.yml"; c.write_text(c.read_text().split("\n", 1)[1])
    run("uninstall")
    assert c.exists()

def test_no_lazygit_leaves_it_alone(home):
    h, run = home; stub(run, "lazygit")
    run("install", "--no-lazygit")
    assert not (h / ".config/lazygit").exists()
```

- [ ] **Step 2: Run to verify they fail**

Run: `python3 -m pytest apps/tests -q -k lazygit`
Expected: FAIL.

- [ ] **Step 3: Implement the lazygit section in `package/apps.sh`**

`lazygit_present` (`command -v lazygit`); `lazygit_install`: absent or empty file → record `absent`/`empty` (only when no record exists yet) and copy; first line is the marker → refresh the copy; otherwise say "lazygit: you have your own config.yml; left as it is". `lazygit_uninstall`: only when the first line is the marker, restore what the record says (delete, or truncate to empty), then drop the record. Wire flag, calls, status, usage.

- [ ] **Step 4: Run all app tests**

Run: `python3 -m pytest apps/tests -q`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add package/apps.sh apps/tests/test_apps.py
git commit -m "feat(apps): install, report and remove the lazygit theme"
```

### Task 6: install.sh flags, docs and the whole suite

**Files:**
- Modify: `package/install.sh` (the `APP_OPTS` case and `--help`), `package/README.md` and `README.md` (app themes section), `apps/tests/test_apps.py` (`test_install_sh_passes_the_app_options_through`)

**Interfaces:**
- Consumes: the `--no-zed` and `--no-lazygit` flags from Tasks 4 and 5.

- [ ] **Step 1: Update the test so it fails**

Change the asserted case line to
`'--no-obsidian|--no-firefox|--no-zed|--no-lazygit|--firefox-chrome|--firefox-theme|--firefox-profile=*) APP_OPTS+=("$a")'`.

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m pytest apps/tests -q -k passes_the_app_options`
Expected: FAIL.

- [ ] **Step 3: Pass the flags through and document them**

Add the two flags to that case in `install.sh` and to its `--help` text; in both READMEs add Zed and lazygit to the app themes, saying what install changes and how uninstall puts it back (one short paragraph each, same tone as the Obsidian and Firefox entries).

- [ ] **Step 4: Run every check**

Run: `python3 -m pytest apps/tests -q && bash apps/tests/package-apps.sh && bash -n package/apps.sh package/install.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add package/install.sh package/README.md README.md apps/tests/test_apps.py
git commit -m "feat(install): --no-zed and --no-lazygit, and the docs for both themes"
```

### Task 7: Live review (with Diego)

**Files:** none committed unless a capture shows something off (then a fix in the owning task's files, test first).

- [ ] **Step 1: Build and install from the branch**

Build the dist, then run its `apps.sh install` with the real HOME (only Zed and lazygit change; Obsidian and Firefox are already Crate and the records make a second run a no-op). Confirm `apps.sh status` shows `Zed installed; Crate selected` and `lazygit Crate theme`.

- [ ] **Step 2: Capture**

With the pointer parked on the target monitor: Zed with a Python and a Rust file plus its terminal panel; lazygit in a repo with changes; btop; yazi; neovim on a source file, each in kitty. grim each window into the scratchpad.

- [ ] **Step 3: Review with Diego**

Show the captures; fix anything off in Zed or lazygit; for btop, yazi or neovim, say what is off and propose the change before making it. A release (version bump, tag, signed repo) only on Diego's go.
