"""run: python3 -m pytest apps/tests -q

The app themes (apps/build.py) and their installer (package/apps.sh), run
against a throwaway HOME: never a real Obsidian vault or Firefox profile.
"""
import json
import os
import re
import subprocess
import sys
import zipfile

import pytest

APPS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(APPS)
APPS_SH = os.path.join(ROOT, "package", "apps.sh")
sys.path.insert(0, APPS)

import build  # noqa: E402

TOKENS = json.load(open(os.path.join(APPS, "tokens.json")))


def rgb(hex_colour):
    h = hex_colour.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


@pytest.fixture(scope="module")
def out(tmp_path_factory):
    d = tmp_path_factory.mktemp("apps")
    assert build.main(["build.py", str(d)]) == 0
    return d


# ---------- the built themes ----------

def test_obsidian_theme_inlines_every_font(out):
    css = (out / "obsidian/Crate/theme.css").read_text()
    assert "crate-font:" not in css
    assert len(re.findall(r'url\("data:font/woff2;base64,', css)) == 3
    for family in ("Roboto", "Bricolage Grotesque", "JetBrains Mono"):
        assert f'font-family: "{family}"' in css


def test_obsidian_theme_loads_nothing_remote(out):
    css = (out / "obsidian/Crate/theme.css").read_text()
    assert not re.search(r"url\(\s*[\"']?(https?:)?//", css)
    assert "@import" not in css


def test_obsidian_manifest_follows_the_community_rules():
    m = json.load(open(os.path.join(APPS, "obsidian/manifest.json")))
    assert {"name", "version", "minAppVersion", "author"} <= m.keys()
    assert re.fullmatch(r"\d+\.\d+\.\d+", m["version"])
    assert "theme" not in m["name"].lower() and "obsidian" not in m["name"].lower()


def test_obsidian_dark_colours_are_crate():
    css = open(os.path.join(APPS, "obsidian/theme.css")).read()
    dark = css[css.index(".theme-dark {"):]
    dark = dark[:dark.index("\n}\n")]
    for token in ("canvas", "object", "popover", "text", "text_secondary", "text_faint", "hairline",
                  "accent", "accent_hi", "warning", "danger"):
        assert TOKENS[token] in dark, token
    assert "--background-primary: var(--crate-canvas)" in dark
    assert "--background-modifier-border: var(--crate-hairline)" in dark
    assert "--interactive-accent: var(--crate-accent)" in dark
    assert "--text-accent: var(--crate-accent-hi)" in dark


def test_obsidian_shape_and_type_apply_in_both_modes():
    css = open(os.path.join(APPS, "obsidian/theme.css")).read()
    body = css[css.index("\nbody {"):]
    body = body[:body.index("\n}\n")]
    assert "--radius-m: 6px" in body
    assert '--font-interface-theme: "Roboto"' in body
    assert "--h1-font: var(--crate-font-display)" in body
    assert "--h6-letter-spacing: var(--crate-label-tracking)" in body
    assert "--crate-label-tracking: 0.12em" in body


def test_firefox_theme_matches_the_tokens(out):
    m = json.load(open(os.path.join(APPS, "firefox/theme/manifest.json")))
    c = m["theme"]["colors"]
    assert c["frame"] == c["toolbar"] == c["ntp_background"] == TOKENS["canvas"]
    assert c["tab_text"] == c["toolbar_text"] == TOKENS["text"]
    assert c["toolbar_field_border_focus"] == c["tab_line"] == TOKENS["accent_hi"]
    assert m["theme"]["properties"]["color_scheme"] == "dark"
    assert m["browser_specific_settings"]["gecko"]["id"] == "crate-theme@cratemusic.app"
    with zipfile.ZipFile(out / "firefox/crate-theme-1.0.0.xpi") as z:
        assert json.loads(z.read("manifest.json")) == m


def test_firefox_chrome_layer_ships_its_fonts(out):
    chrome = out / "firefox/chrome"
    for css in ("userChrome.css", "userContent.css"):
        text = (chrome / css).read_text()
        for url in re.findall(r'url\("(fonts/[^"]+)"\)', text):
            assert (chrome / url).is_file(), url
    assert (chrome / "fonts/OFL-roboto.txt").is_file()


def test_builds_are_reproducible(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    build.main(["build.py", str(a)])
    build.main(["build.py", str(b)])
    for rel in ("firefox/crate-theme-1.0.0.xpi", "obsidian/Crate/theme.css"):
        assert (a / rel).read_bytes() == (b / rel).read_bytes(), rel


# ---------- the installer, in a throwaway home ----------

@pytest.fixture
def home(tmp_path, out):
    h = tmp_path / "home"
    (h / ".config").mkdir(parents=True)
    env = dict(os.environ, HOME=str(h), XDG_CONFIG_HOME=str(h / ".config"),
               XDG_STATE_HOME=str(h / ".local/state"), CRATE_APPS_DIR=str(out),
               PATH="/usr/bin:/bin")

    def run(*args):
        r = subprocess.run(["bash", APPS_SH, *args], env=env, capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        return r.stdout + r.stderr

    return h, run


def make_vaults(h, *names):
    vaults = {}
    for i, name in enumerate(names):
        v = h / name
        (v / ".obsidian").mkdir(parents=True)
        (v / ".obsidian/appearance.json").write_text('{"cssTheme":"Nord","enabledCssSnippets":["mine"]}')
        vaults[f"id{i}"] = {"path": str(v), "ts": 1, "open": i == 0}
    vaults["gone"] = {"path": str(h / "moved-away"), "ts": 1}
    (h / ".config/obsidian").mkdir(parents=True)
    (h / ".config/obsidian/obsidian.json").write_text(json.dumps({"vaults": vaults}))
    return [h / n for n in names]


def test_obsidian_install_copies_into_every_vault_and_never_touches_appearance(home, out):
    h, run = home
    a, b = make_vaults(h, "Notes", "Work")
    before = (a / ".obsidian/appearance.json").read_bytes()
    log = run("install")
    assert "2 vault(s)" in log
    for v in (a, b):
        theme = v / ".obsidian/themes/Crate"
        assert (theme / "theme.css").read_bytes() == (out / "obsidian/Crate/theme.css").read_bytes()
        assert json.loads((theme / "manifest.json").read_text())["name"] == "Crate"
    assert (a / ".obsidian/appearance.json").read_bytes() == before
    assert not (h / "moved-away").exists()
    run("install")  # idempotent
    assert "2 of 2 vault(s), selected in 0" in run("status")


def test_obsidian_leaves_a_crate_theme_it_did_not_install(home):
    h, run = home
    (a,) = make_vaults(h, "Notes")
    theirs = a / ".obsidian/themes/Crate"
    theirs.mkdir(parents=True)
    (theirs / "theme.css").write_text("/* from the community store, another version */")
    assert "not ours" in run("install")
    run("uninstall")
    assert (theirs / "theme.css").read_text().startswith("/* from the community store")


def test_obsidian_uninstall_removes_only_unchanged_copies(home):
    h, run = home
    a, b = make_vaults(h, "Notes", "Work")
    run("install")
    edited = b / ".obsidian/themes/Crate/theme.css"
    edited.write_text(edited.read_text() + "\n/* my tweak */\n")
    log = run("uninstall")
    assert not (a / ".obsidian/themes/Crate").exists()
    assert (a / ".obsidian/themes").is_dir()
    assert edited.is_file() and "changed since install" in log


def make_firefox(h, chrome_symlink=True, pref=True):
    base = h / ".mozilla/firefox"
    main, other = base / "abc.default-release", base / "xyz.default"
    for p in (main, other):
        p.mkdir(parents=True)
    (base / "profiles.ini").write_text(
        "[Install4F96D1932A9F858E]\nDefault=abc.default-release\nLocked=1\n\n"
        "[Profile1]\nName=default\nIsRelative=1\nPath=xyz.default\nDefault=1\n\n"
        "[Profile0]\nName=default-release\nIsRelative=1\nPath=abc.default-release\n\n"
        "[General]\nStartWithLastProfile=1\nVersion=2\n")
    themes = base / "firefox-themes"
    themes.mkdir()
    (themes / "userChrome.css").write_text('@import "WhiteSur/theme.css";\n')
    if chrome_symlink:
        (main / "chrome").symlink_to(themes)
    else:
        (main / "chrome").mkdir()
        (main / "chrome/userChrome.css").write_text("/* mine */\n")
    if pref:
        (main / "user.js").write_text('user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n')
    return main, other, themes


def test_firefox_chrome_is_opt_in(home):
    h, run = home
    main, _, themes = make_firefox(h)
    run("install")
    assert (main / "chrome").is_symlink()


def test_firefox_chrome_replaces_whitesur_and_restores_the_symlink(home, out):
    h, run = home
    main, other, themes = make_firefox(h)
    user_js = (main / "user.js").read_text()
    run("install", "--firefox-chrome")
    chrome = main / "chrome"
    assert chrome.is_dir() and not chrome.is_symlink()
    assert (chrome / "userChrome.css").read_bytes() == (out / "firefox/chrome/userChrome.css").read_bytes()
    assert (chrome / "fonts/roboto-latin.woff2").is_file()
    backup = main / "chrome.before-crate"
    assert backup.is_symlink() and os.readlink(backup) == str(themes)
    assert (themes / "userChrome.css").read_text().startswith('@import "WhiteSur')
    assert (main / "user.js").read_text() == user_js  # the pref was already there
    assert not (other / "chrome").exists()  # only the profile Firefox starts with
    assert "yes (1 profile(s))" in run("status")

    run("install", "--firefox-chrome")  # a second run refreshes, keeps the backup
    assert backup.is_symlink()

    run("uninstall")
    assert chrome.is_symlink() and os.readlink(chrome) == str(themes)
    assert not backup.exists() and not backup.is_symlink()
    assert (themes / "userChrome.css").read_text().startswith('@import "WhiteSur')


def test_firefox_chrome_sets_the_pref_and_takes_it_back(home):
    h, run = home
    main, _, _ = make_firefox(h, chrome_symlink=False, pref=False)
    (main / "user.js").write_text('user_pref("browser.tabs.drawInTitlebar", true);\n')
    run("install", "--firefox-chrome")
    assert '"toolkit.legacyUserProfileCustomizations.stylesheets", true' in (main / "user.js").read_text()
    assert (main / "chrome.before-crate/userChrome.css").read_text() == "/* mine */\n"
    run("uninstall")
    assert (main / "user.js").read_text() == 'user_pref("browser.tabs.drawInTitlebar", true);\n'
    assert (main / "chrome/userChrome.css").read_text() == "/* mine */\n"


def test_firefox_chrome_keeps_your_edits_on_uninstall(home):
    h, run = home
    main, _, themes = make_firefox(h)
    run("install", "--firefox-chrome")
    with open(main / "chrome/userChrome.css", "a") as f:
        f.write("\n/* my tweak */\n")
    log = run("uninstall")
    edited = [p for p in main.iterdir() if p.name.startswith("chrome.crate-edited-")]
    assert len(edited) == 1 and "my tweak" in (edited[0] / "userChrome.css").read_text()
    assert (main / "chrome").is_symlink() and "had edits" in log


def test_firefox_profile_can_be_named(home):
    h, run = home
    main, other, _ = make_firefox(h)
    run("install", "--firefox-chrome", "--firefox-profile", str(other))
    assert (other / "chrome/userChrome.css").is_file()
    assert (main / "chrome").is_symlink()


def test_keep_files_uninstall_restores_firefox_only(home, out):
    h, run = home
    (a,) = make_vaults(h, "Notes")
    main, _, themes = make_firefox(h)
    run("install", "--firefox-chrome")
    env = dict(os.environ, HOME=str(h), XDG_CONFIG_HOME=str(h / ".config"),
               XDG_STATE_HOME=str(h / ".local/state"), CRATE_APPS_DIR=str(out),
               CRATE_APPS_ONLY="firefox")
    subprocess.run(["bash", APPS_SH, "uninstall"], env=env, check=True, capture_output=True)
    assert (main / "chrome").is_symlink()
    assert (a / ".obsidian/themes/Crate/theme.css").is_file()
    run("uninstall")
    assert not (a / ".obsidian/themes/Crate").exists()


def test_install_sh_passes_the_app_options_through():
    text = open(os.path.join(ROOT, "package/install.sh")).read()
    assert '--no-obsidian|--firefox-chrome|--firefox-theme|--firefox-profile=*) APP_OPTS+=("$a")' in text
    assert 'bash "$HERE/apps.sh" install' in text
    assert 'bash "$HERE/apps.sh" uninstall' in open(os.path.join(ROOT, "package/uninstall.sh")).read()
    assert 'apps.sh" status' in open(os.path.join(ROOT, "bin/crate-for-ryoku")).read()