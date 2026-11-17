"""run: python3 -m pytest apps/tests -q

The app themes (apps/build.py) and their installer (package/apps.sh), run
against a throwaway HOME: never a real Obsidian vault or Firefox profile.
"""
import base64
import json
import os
import re
import shutil
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


SCHEME = json.load(open(os.path.join(ROOT, "theme/crate/scheme.json")))["dark"]


def crate_bases():
    """Every #rrggbb a Crate app theme may use."""
    bases = {v.lower() for v in TOKENS.values() if isinstance(v, str) and v.startswith("#")}
    for v in TOKENS.values():
        if isinstance(v, str) and v.startswith("rgba("):
            r, g, b = (int(x) for x in v[5:-1].split(",")[:3])
            bases.add("#%02x%02x%02x" % (r, g, b))
    t = SCHEME["terminal"]
    bases |= {v.lower() for v in t.values() if isinstance(v, str)}
    bases |= {v.lower() for group in ("normal", "bright") for v in t[group].values()}
    return bases


def colours(node):
    if isinstance(node, dict):
        for v in node.values():
            yield from colours(v)
    elif isinstance(node, list):
        for v in node:
            yield from colours(v)
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
    assert s["border"].lower() == "#f1f5f91a"  # hairline: text at 0.1


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


def test_crate_terminal_palette_is_cyan_white_and_amber():
    # a near-monochrome console (Diego, 2026-11-17): cyan in six intensities,
    # four greys, amber for warnings and bright (bold) errors, Crate red for
    # deletions and plain errors
    cyan, amber = TOKENS["cyan_scale"], TOKENS["amber_scale"]
    t = SCHEME["terminal"]
    want = {
        "normal": {"black": "#16171d", "red": TOKENS["danger"], "green": cyan["400"],
                   "yellow": amber["500"], "blue": cyan["600"], "magenta": cyan["200"],
                   "cyan": cyan["500"], "white": "#cbd5e1"},
        "bright": {"black": "#4a4c52", "red": amber["400"], "green": cyan["300"],
                   "yellow": amber["400"], "blue": cyan["400"], "magenta": cyan["100"],
                   "cyan": cyan["300"], "white": TOKENS["text"]},
    }
    assert {g: t[g] for g in want} == want
    assert cyan["500"] == TOKENS["accent"] and cyan["300"] == TOKENS["accent_hi"]
    assert amber["400"] == TOKENS["warning"]


def over_canvas(token):
    r, g, b, a = (float(x) for x in TOKENS[token][5:-1].split(","))
    c = rgb(TOKENS["canvas"])
    return "#%02x%02x%02x" % tuple(round(a * v + (1 - a) * w) for v, w in zip((r, g, b), c))


def test_lazygit_theme_is_marked_and_crate(out):
    text = (out / "lazygit/config.yml").read_text()
    assert text.splitlines()[0] == "# crate-for-ryoku: lazygit"
    assert "activeBorderColor:" in text and TOKENS["accent"] in text
    assert over_canvas("hairline") in text  # inactive border, solid
    found = {c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}\b", text)}
    allowed = crate_bases() | {over_canvas(t) for t in ("hairline", "text_secondary", "text_faint")}
    assert found and found <= allowed


def test_nvim_syntax_is_crate_and_marked(out):
    text = (out / "nvim/crate.lua").read_text()
    assert text.splitlines()[0] == "-- crate-for-ryoku: neovim"
    assert '"folke/tokyonight.nvim"' in text and "on_highlights" in text
    found = {c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}\b", text)}
    allowed = crate_bases() | {over_canvas(t) for t in ("hairline", "text_secondary", "text_faint")}
    assert found and found <= allowed
    # the sober syntax: amber only for numbers, constants and escapes
    for group, token in (("Keyword", "accent"), ("Function", "accent"), ("String", "accent_hi"),
                         ("Number", "warning")):
        assert re.search(r'%s = \{ fg = "%s"' % (re.escape(group), TOKENS[token]), text), group
    assert re.search(r'Comment = \{ fg = "%s", italic = true' % over_canvas("text_faint"), text)


def test_gtk_css_is_crate(out):
    css = (out / "gtk/crate.css").read_text()
    allowed = {v.lower() for v in TOKENS.values() if isinstance(v, str) and v.startswith("#")}
    assert {c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}\b", css)} <= allowed
    rgba = {v.replace(" ", "") for v in TOKENS.values() if isinstance(v, str) and v.startswith("rgba(")}
    assert {c.replace(" ", "") for c in re.findall(r"rgba\([^)]*\)", css)} <= rgba
    for decl in ("--dialog-bg-color: #111218;", "--thumbnail-bg-color: #111218;",
                 "--headerbar-border-color: rgba(241, 245, 249, 0.1);", "--window-radius: 6px;"):
        assert decl in css, decl
    assert "border-radius: 6px;" in css


def test_gtk3_css_has_no_libadwaita_variables(out):
    # GTK 3 rejects :root and custom properties and drops the whole sheet
    css = (out / "gtk/crate-gtk3.css").read_text()
    assert ":root" not in css and not re.search(r"--[a-z-]+\s*:", css)
    assert "@define-color dialog_bg_color #111218;" in css and "border-radius: 6px;" in css
    allowed = {v.lower() for v in TOKENS.values() if isinstance(v, str) and v.startswith("#")}
    assert {c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}\b", css)} <= allowed


def test_gtksourceview_scheme_is_crate(out):
    import xml.etree.ElementTree as ET
    root = ET.parse(out / "gtksourceview/crate.xml").getroot()
    assert root.tag == "style-scheme" and root.get("id") == "crate" and root.get("name") == "Crate"
    props = {p.get("name"): p.text for p in root.iter("property")}
    assert props.get("variant") == "dark"
    styles = {st.get("name"): st for st in root.iter("style")}
    assert styles["def:keyword"].get("foreground") == TOKENS["accent"]
    assert styles["def:string"].get("foreground") == TOKENS["accent_hi"]
    assert styles["def:number"].get("foreground") == TOKENS["warning"]
    comment = styles["def:comment"]
    assert comment.get("foreground") == over_canvas("text_faint") and comment.get("italic") == "true"
    allowed = crate_bases() | {over_canvas(t) for t in ("hairline", "text_secondary", "text_faint")}
    used = set()
    for st in root.iter("style"):
        for attr in ("foreground", "background"):
            v = st.get(attr)
            if v:
                used.add(v.lower()[:7])
    assert used and used <= allowed


def test_gtk_css_leaves_buttons_entries_and_osd_to_libadwaita(out):
    # a user sheet outranks the theme: a corner rule on buttons or entries
    # rounds the inner corners of linked groups and squares round titlebuttons
    for name in ("gtk/crate.css", "gtk/crate-gtk3.css"):
        css = (out / name).read_text()
        for rule in re.findall(r"([^{}]+)\{([^}]*)\}", css):
            if "border-radius" in rule[1]:
                sel = rule[0]
                assert not re.search(r"\b(button|entry|spinbutton)\b|\.osd", sel), (name, sel.strip())


def test_lazygit_hides_the_amber_random_tip(out):
    # the tip draws in ANSI yellow: amber that is no status (Diego, 2026-11-17)
    assert "\n  showRandomTip: false\n" in (out / "lazygit/config.yml").read_text()


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


def test_firefox_settings_nav_is_a_cyan_mark_not_a_pill(out):
    text = (out / "firefox/chrome/userContent.css").read_text()
    # the overrides sit on the component hosts, where Nova redeclares them
    assert re.search(r"moz-page-nav-button,\s*moz-input-search", text)
    decls = dict(re.findall(r"(--[\w-]+):\s*([^;]+?)\s*!important;", text))
    assert decls["--page-nav-button-background-color-selected"] == "rgba(6, 182, 212, 0.1)"
    assert decls["--page-nav-button-indicator-width"] == "2px"
    assert decls["--page-nav-button-border-radius"] == "6px"
    assert decls["--input-search-border-radius"] == "6px"


def test_firefox_tabs_sit_off_the_strip_edges(out):
    text = (out / "firefox/chrome/userChrome.css").read_text()
    assert "--tab-margin-block: 6px !important;" in text
    assert re.search(r"#TabsToolbar\s*\{\s*padding-inline: 6px !important;", text)


def test_chrome_theme_has_a_fixed_id_and_crate_colours(out):
    m = json.load(open(out / "chrome/crate-theme/manifest.json"))
    assert build.chrome_id(m["key"]) == "jddiejdibphncbpfehopofclalbeghbc"
    assert "CHROME_ID=jddiejdibphncbpfehopofclalbeghbc" in open(APPS_SH).read()
    c = m["theme"]["colors"]
    assert c["frame"] == rgb(TOKENS["canvas"])
    assert c["tab_text"] == rgb(TOKENS["text"])
    assert c["ntp_link"] == rgb(TOKENS["accent_hi"])
    # the key is a public key only: an RSA SubjectPublicKeyInfo, no private part
    der = base64.b64decode(m["key"])
    assert der[:3] == b"\x30\x82\x01" and len(der) < 400


def test_chrome_webstore_zip_drops_the_key(out):
    with zipfile.ZipFile(out / "chrome/crate-theme-1.0.0-webstore.zip") as z:
        m = json.loads(z.read("manifest.json"))
    assert "key" not in m and m["theme"]


def test_builds_are_reproducible(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    build.main(["build.py", str(a)])
    build.main(["build.py", str(b)])
    for rel in ("firefox/crate-theme-1.0.0.xpi", "chrome/crate-theme-1.0.0-webstore.zip",
                "obsidian/Crate/theme.css"):
        assert (a / rel).read_bytes() == (b / rel).read_bytes(), rel


# ---------- the Chrome .crx, with a throwaway key ----------

def make_key(tmp_path):
    key = tmp_path / "throwaway.pem"
    subprocess.run(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048",
                    "-out", str(key)], check=True, capture_output=True)
    return key


def test_crx_is_signed_and_carries_the_keys_id(tmp_path):
    key = make_key(tmp_path)
    theme = tmp_path / "theme"
    theme.mkdir()
    pub = base64.b64encode(build.public_key_der(str(key))).decode()
    (theme / "manifest.json").write_text(json.dumps({"manifest_version": 3, "name": "t", "version": "1.0.0",
                                                     "key": pub, "theme": {}}))
    crx = tmp_path / "t.crx"
    crx_id = build.pack_crx(str(theme), str(key), str(crx))
    assert crx_id == build.chrome_id(pub)
    assert build.verify_crx(str(crx)) == crx_id
    data = crx.read_bytes()
    assert data[:4] == b"Cr24" and data[4:8] == b"\x03\x00\x00\x00"
    parts = build.read_crx(str(crx))
    with zipfile.ZipFile(__import__("io").BytesIO(parts["zip"])) as z:
        assert json.loads(z.read("manifest.json"))["key"] == pub
    # a flipped byte in the zip breaks the signature
    bad = tmp_path / "bad.crx"
    bad.write_bytes(data[:-10] + bytes([data[-10] ^ 1]) + data[-9:])
    with pytest.raises(SystemExit):
        build.verify_crx(str(bad))


def test_build_refuses_a_key_that_is_not_the_manifests(tmp_path):
    key = make_key(tmp_path)
    with pytest.raises(SystemExit, match="not the key in the Chrome manifest"):
        build.main(["build.py", str(tmp_path / "out"), "--chrome-key", str(key)])
    assert not list((tmp_path / "out/chrome").glob("*.crx"))


# ---------- the installer, in a throwaway home ----------

# the commands apps.sh uses; PATH holds only these, so a browser or Obsidian on
# this machine never counts as installed unless a test puts a stub there
TOOLS = ("bash", "python3", "sha256sum", "cut", "grep", "mkdir", "touch", "cp", "mv", "cmp", "rm", "rmdir",
         "find", "sort", "xargs", "cat", "date", "ls", "head", "dirname", "env", "sed")


@pytest.fixture
def home(tmp_path, out):
    h = tmp_path / "home"
    (h / ".config").mkdir(parents=True)
    bindir = tmp_path / "bin"
    bindir.mkdir()
    for tool in TOOLS:
        os.symlink(shutil.which(tool), bindir / tool)
    env = dict(os.environ, HOME=str(h), XDG_CONFIG_HOME=str(h / ".config"),
               XDG_STATE_HOME=str(h / ".local/state"), CRATE_APPS_DIR=str(out),
               CRATE_SYSTEM_ROOT=str(tmp_path / "root"), PATH=str(bindir))

    def run(*args, **extra):
        r = subprocess.run([shutil.which("bash"), APPS_SH, *args], env=dict(env, **extra),
                           capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        return r.stdout + r.stderr

    run.bindir = bindir
    run.root = tmp_path / "root"
    return h, run


def stub(run, name):
    """A command that does nothing, so apps.sh sees that app as installed."""
    path = run.bindir / name
    path.write_text("#!/bin/sh\nexit 0\n")
    path.chmod(0o755)


def appearance(vault):
    return json.loads((vault / ".obsidian/appearance.json").read_text())


def make_vaults(h, *names, appearance_json='{"cssTheme":"Nord","enabledCssSnippets":["mine"],"baseFontSize":17}'):
    vaults = {}
    for i, name in enumerate(names):
        v = h / name
        (v / ".obsidian").mkdir(parents=True)
        if appearance_json is not None:
            (v / ".obsidian/appearance.json").write_text(appearance_json)
        vaults[f"id{i}"] = {"path": str(v), "ts": 1, "open": i == 0}
    vaults["gone"] = {"path": str(h / "moved-away"), "ts": 1}
    (h / ".config/obsidian").mkdir(parents=True)
    (h / ".config/obsidian/obsidian.json").write_text(json.dumps({"vaults": vaults}))
    return [h / n for n in names]


def test_nothing_installed_installs_quietly(home):
    h, run = home
    log = run("install")
    assert "Obsidian" not in log and "Firefox" not in log
    status = run("status")
    assert re.search(r"Obsidian +not installed", status)
    assert re.search(r"Firefox +not installed", status)
    assert re.search(r"Chrome +not installed", status)
    run("uninstall")
    assert not (h / ".mozilla").exists()


def test_obsidian_without_vaults_is_one_line(home):
    h, run = home
    stub(run, "obsidian")
    log = run("install")
    assert len(log.splitlines()) == 1 and "no vaults yet" in log
    assert "Crate in 0 of 0 vault(s)" in run("status")


def test_obsidian_install_copies_and_selects_crate_keeping_every_other_key(home, out):
    h, run = home
    a, b = make_vaults(h, "Notes", "Work")
    log = run("install")
    assert "2 vault(s), selected in 2" in log and "reopen" in log
    for v in (a, b):
        theme = v / ".obsidian/themes/Crate"
        assert (theme / "theme.css").read_bytes() == (out / "obsidian/Crate/theme.css").read_bytes()
        assert json.loads((theme / "manifest.json").read_text())["name"] == "Crate"
        assert appearance(v) == {"cssTheme": "Crate", "enabledCssSnippets": ["mine"], "baseFontSize": 17}
    assert not (h / "moved-away").exists()
    run("install")  # idempotent
    assert "Crate in 2 of 2 vault(s), selected in 2" in run("status")
    run("uninstall")
    for v in (a, b):
        assert appearance(v) == {"cssTheme": "Nord", "enabledCssSnippets": ["mine"], "baseFontSize": 17}
        assert not (v / ".obsidian/themes/Crate").exists()


def test_obsidian_vault_on_the_default_theme_goes_back_to_it(home):
    h, run = home
    (a,) = make_vaults(h, "Notes", appearance_json='{"accentColor":"#ff0000"}')
    run("install")
    assert appearance(a) == {"accentColor": "#ff0000", "cssTheme": "Crate"}
    run("uninstall")
    assert appearance(a) == {"accentColor": "#ff0000"}


def test_obsidian_empty_css_theme_is_put_back_as_it_was(home):
    h, run = home
    (a,) = make_vaults(h, "Notes", appearance_json='{"cssTheme":""}')
    run("install")
    run("uninstall")
    assert appearance(a) == {"cssTheme": ""}


def test_obsidian_creates_a_missing_appearance_json_and_removes_it_again(home):
    h, run = home
    (a,) = make_vaults(h, "Notes", appearance_json=None)
    run("install")
    assert appearance(a) == {"cssTheme": "Crate"}
    run("uninstall")
    assert not (a / ".obsidian/appearance.json").exists()


def test_obsidian_uninstall_leaves_a_theme_you_picked_since(home):
    h, run = home
    a, b = make_vaults(h, "Notes", "Work")
    run("install")
    (b / ".obsidian/appearance.json").write_text('{"cssTheme":"Minimal","enabledCssSnippets":["mine"]}')
    log = run("install")  # a later install respects the pick too
    assert "uses Minimal since" in log and appearance(b)["cssTheme"] == "Minimal"
    log = run("uninstall")
    assert appearance(a)["cssTheme"] == "Nord"
    assert appearance(b) == {"cssTheme": "Minimal", "enabledCssSnippets": ["mine"]}
    assert "another theme selected now" in log


def test_obsidian_turns_ryokus_snippet_off_and_back_on(home):
    h, run = home
    (a,) = make_vaults(h, "Notes", appearance_json='{"enabledCssSnippets":["mine","ryoku"]}')
    run("install")
    assert appearance(a) == {"enabledCssSnippets": ["mine"], "cssTheme": "Crate"}
    assert "greys it out" not in run("status")
    # stock Ryoku's doctor puts it back over the theme: status says so
    (a / ".obsidian/appearance.json").write_text('{"enabledCssSnippets":["mine","ryoku"],"cssTheme":"Crate"}')
    assert "palette snippet is on in 1" in run("status")
    (a / ".obsidian/appearance.json").write_text('{"enabledCssSnippets":["mine"],"cssTheme":"Crate"}')
    run("uninstall")
    assert appearance(a) == {"enabledCssSnippets": ["mine", "ryoku"]}


def test_obsidian_snippet_stays_off_when_the_old_theme_comes_back(home):
    h, run = home
    (a,) = make_vaults(h, "Notes", appearance_json='{"cssTheme":"Nord","enabledCssSnippets":["ryoku"]}')
    run("install")
    run("uninstall")
    # a vault with its own theme keeps the snippet off, as Ryoku's doctor would
    assert appearance(a) == {"cssTheme": "Nord", "enabledCssSnippets": []}


def test_obsidian_invalid_appearance_json_is_left_alone(home):
    h, run = home
    (a,) = make_vaults(h, "Notes", appearance_json="{not json")
    log = run("install")
    assert "not valid JSON" in log
    assert (a / ".obsidian/themes/Crate/theme.css").is_file()
    assert (a / ".obsidian/appearance.json").read_text() == "{not json"
    run("uninstall")
    assert (a / ".obsidian/appearance.json").read_text() == "{not json"


def test_obsidian_leaves_a_crate_theme_it_did_not_install(home):
    h, run = home
    (a,) = make_vaults(h, "Notes")
    theirs = a / ".obsidian/themes/Crate"
    theirs.mkdir(parents=True)
    (theirs / "theme.css").write_text("/* from the community store, another version */")
    assert "not ours" in run("install")
    assert appearance(a)["cssTheme"] == "Nord"
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


def test_no_obsidian_leaves_vaults_alone(home):
    h, run = home
    (a,) = make_vaults(h, "Notes")
    before = (a / ".obsidian/appearance.json").read_bytes()
    run("install", "--no-obsidian")
    assert not (a / ".obsidian/themes").exists()
    assert (a / ".obsidian/appearance.json").read_bytes() == before


def make_firefox(h, chrome="symlink", pref=True):
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
    if chrome == "symlink":
        (main / "chrome").symlink_to(themes)
    elif chrome == "dir":
        (main / "chrome").mkdir()
        (main / "chrome/userChrome.css").write_text("/* mine */\n")
    if pref:
        (main / "user.js").write_text('user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n')
    return main, other, themes


def test_firefox_chrome_replaces_whitesur_by_default_and_restores_the_symlink(home, out):
    h, run = home
    main, other, themes = make_firefox(h)
    user_js = (main / "user.js").read_text()
    log = run("install")
    assert "restart Firefox" in log
    chrome = main / "chrome"
    assert chrome.is_dir() and not chrome.is_symlink()
    assert (chrome / "userChrome.css").read_bytes() == (out / "firefox/chrome/userChrome.css").read_bytes()
    assert (chrome / "fonts/roboto-latin.woff2").is_file()
    backup = main / "chrome.before-crate"
    assert backup.is_symlink() and os.readlink(backup) == str(themes)
    assert (themes / "userChrome.css").read_text().startswith('@import "WhiteSur')
    assert (main / "user.js").read_text() == user_js  # the pref was already there
    assert not (other / "chrome").exists()  # only the profile Firefox starts with
    assert "Crate userChrome in 1 of 1 profile(s)" in run("status")

    run("install")  # a second run refreshes, keeps the backup
    assert backup.is_symlink()

    run("uninstall")
    assert chrome.is_symlink() and os.readlink(chrome) == str(themes)
    assert not backup.exists() and not backup.is_symlink()
    assert (themes / "userChrome.css").read_text().startswith('@import "WhiteSur')
    assert "Crate userChrome in 0 of 1 profile(s)" in run("status")


def test_firefox_chrome_flag_is_still_accepted(home):
    h, run = home
    main, _, _ = make_firefox(h)
    run("install", "--firefox-chrome")
    assert (main / "chrome/.crate-for-ryoku").is_file()


def test_no_firefox_leaves_the_profile_alone(home):
    h, run = home
    main, _, themes = make_firefox(h)
    log = run("install", "--no-firefox")
    assert (main / "chrome").is_symlink() and "Firefox" not in log
    assert not (main / "chrome.before-crate").exists()


def test_firefox_profile_without_a_chrome_folder(home):
    h, run = home
    main, _, _ = make_firefox(h, chrome=None, pref=False)
    run("install")
    assert (main / "chrome/userChrome.css").is_file()
    assert not (main / "chrome.before-crate").exists()
    assert '"toolkit.legacyUserProfileCustomizations.stylesheets", true' in (main / "user.js").read_text()
    run("uninstall")
    assert not (main / "chrome").exists() and not (main / "chrome.before-crate").exists()
    assert "legacyUserProfileCustomizations" not in (main / "user.js").read_text()


def test_firefox_chrome_sets_the_pref_and_takes_it_back(home):
    h, run = home
    main, _, _ = make_firefox(h, chrome="dir", pref=False)
    (main / "user.js").write_text('user_pref("browser.tabs.drawInTitlebar", true);\n')
    run("install")
    assert '"toolkit.legacyUserProfileCustomizations.stylesheets", true' in (main / "user.js").read_text()
    assert (main / "chrome.before-crate/userChrome.css").read_text() == "/* mine */\n"
    run("uninstall")
    assert (main / "user.js").read_text() == 'user_pref("browser.tabs.drawInTitlebar", true);\n'
    assert (main / "chrome/userChrome.css").read_text() == "/* mine */\n"


def test_firefox_chrome_keeps_your_edits_on_uninstall(home):
    h, run = home
    main, _, themes = make_firefox(h)
    run("install")
    with open(main / "chrome/userChrome.css", "a") as f:
        f.write("\n/* my tweak */\n")
    log = run("uninstall")
    edited = [p for p in main.iterdir() if p.name.startswith("chrome.crate-edited-")]
    assert len(edited) == 1 and "my tweak" in (edited[0] / "userChrome.css").read_text()
    assert (main / "chrome").is_symlink() and "had edits" in log


def test_firefox_profile_can_be_named(home):
    h, run = home
    main, other, _ = make_firefox(h)
    run("install", "--firefox-profile", str(other))
    assert (other / "chrome/userChrome.css").is_file()
    assert (main / "chrome").is_symlink()


def test_firefox_installed_without_a_profile_is_one_line(home):
    h, run = home
    stub(run, "firefox")
    log = run("install")
    assert len(log.splitlines()) == 1 and "no profile yet" in log
    assert re.search(r"Firefox +installed; Crate userChrome in 0 of 0", run("status"))


def test_firefox_status_names_the_add_ons(home):
    h, run = home
    main, _, _ = make_firefox(h)
    (main / "extensions.json").write_text(json.dumps({"addons": [
        {"id": "crate-theme@cratemusic.app", "active": True},
        {"id": "ryoku-theme@ryoku.arch", "active": True}]}))
    status = run("status")
    assert re.search(r"Firefox theme add-on +yes \(the Ryoku Theme extension recolours Firefox over it\)", status)


def test_look_only_uninstall_restores_the_looks_and_keeps_the_files(home, out):
    h, run = home
    (a,) = make_vaults(h, "Notes")
    main, _, themes = make_firefox(h)
    run("install")
    run("uninstall", "--look-only")
    assert (main / "chrome").is_symlink()
    assert appearance(a)["cssTheme"] == "Nord"
    assert (a / ".obsidian/themes/Crate/theme.css").is_file()
    run("uninstall")
    assert not (a / ".obsidian/themes/Crate").exists()
    assert appearance(a)["cssTheme"] == "Nord"


def test_the_pre_07_keep_files_switch_still_means_look_only(home):
    h, run = home
    (a,) = make_vaults(h, "Notes")
    run("install")
    run("uninstall", CRATE_APPS_ONLY="firefox")
    assert appearance(a)["cssTheme"] == "Nord"
    assert (a / ".obsidian/themes/Crate/theme.css").is_file()


def make_chrome_package(root):
    (root / "usr/share/crate-for-ryoku/chrome").mkdir(parents=True)
    (root / "usr/share/crate-for-ryoku/chrome/crate-theme.crx").write_bytes(b"Cr24")
    (root / "usr/share/google-chrome/extensions").mkdir(parents=True)
    (root / "usr/share/google-chrome/extensions/jddiejdibphncbpfehopofclalbeghbc.json").write_text("{}")


def test_chrome_status_reports_the_package_and_the_selection(home):
    h, run = home
    stub(run, "google-chrome-stable")
    assert re.search(r"Chrome +installed \(google-chrome-stable\); Crate theme not packaged", run("status"))
    make_chrome_package(run.root)
    prefs = h / ".config/google-chrome/Default/Preferences"
    prefs.parent.mkdir(parents=True)
    prefs.write_text(json.dumps({"extensions": {"theme": {"id": "jddiejdibphncbpfehopofclalbeghbc"}}}))
    other = h / ".config/google-chrome/Profile 1/Preferences"
    other.parent.mkdir(parents=True)
    other.write_text(json.dumps({"extensions": {"theme": {"id": ""}}}))
    assert "Crate theme offered by the package, selected in 1 profile(s)" in run("status")
    log = run("install")  # nothing per user for Chrome
    assert "Chrome" not in log


def test_chrome_package_without_a_browser(home):
    h, run = home
    make_chrome_package(run.root)
    assert re.search(r"Chrome +not installed; Crate theme packaged", run("status"))


# ---------- Zed ----------

ZED_DEFAULT = ('// Zed\n{\n  "theme": {\n    "mode": "system",\n    "light": "One Light",\n'
               '    "dark": "One Dark"\n  }\n}\n')


def test_zed_install_selects_crate_and_uninstall_puts_one_dark_back(home, out):
    h, run = home
    stub(run, "zed")
    s = h / ".config/zed/settings.json"
    s.parent.mkdir(parents=True)
    s.write_text(ZED_DEFAULT)
    run("install")
    assert (h / ".config/zed/themes/crate.json").read_bytes() == (out / "zed/crate.json").read_bytes()
    assert '"dark": "Crate"' in s.read_text()
    assert re.search(r"Zed +installed; Crate selected", run("status"))
    run("uninstall")
    assert s.read_text() == ZED_DEFAULT
    assert not (h / ".config/zed/themes/crate.json").exists()


def test_zed_second_install_keeps_a_theme_picked_since(home):
    h, run = home
    stub(run, "zed")
    s = h / ".config/zed/settings.json"
    s.parent.mkdir(parents=True)
    s.write_text(ZED_DEFAULT)
    run("install")
    s.write_text(s.read_text().replace('"Crate"', '"Gruvbox"'))
    log = run("install")
    assert '"Gruvbox"' in s.read_text() and "Gruvbox" in log
    assert re.search(r"Zed +installed; Crate not selected", run("status"))


def test_zed_never_started_gets_a_settings_file_and_loses_it_again(home):
    h, run = home
    stub(run, "zed")
    run("install")
    assert '"dark": "Crate"' in (h / ".config/zed/settings.json").read_text()
    run("uninstall")
    assert not (h / ".config/zed/settings.json").exists()


def test_zed_uninstall_keeps_an_edited_theme_file(home):
    h, run = home
    stub(run, "zed")
    run("install")
    t = h / ".config/zed/themes/crate.json"
    t.write_text(t.read_text() + "\n")
    run("uninstall")
    assert t.exists()


def test_zed_keeps_the_theme_file_while_settings_still_select_it(home):
    h, run = home
    stub(run, "zed")
    s = h / ".config/zed/settings.json"
    s.parent.mkdir(parents=True)
    s.write_text(ZED_DEFAULT)
    run("install")
    s.write_text('{ "theme": "Crate" }')  # Crate picked again, another way
    run("uninstall")
    assert (h / ".config/zed/themes/crate.json").exists()


def test_no_zed_leaves_zed_alone(home):
    h, run = home
    stub(run, "zed")
    run("install", "--no-zed")
    assert not (h / ".config/zed").exists()


def test_zed_not_installed_is_reported(home):
    h, run = home
    assert re.search(r"Zed +not installed", run("status"))


# ---------- lazygit ----------

def test_lazygit_empty_config_gets_crate_and_goes_back_to_empty(home, out):
    h, run = home
    stub(run, "lazygit")
    c = h / ".config/lazygit/config.yml"
    c.parent.mkdir(parents=True)
    c.write_text("")
    run("install")
    assert c.read_bytes() == (out / "lazygit/config.yml").read_bytes()
    assert re.search(r"lazygit +Crate theme", run("status"))
    run("uninstall")
    assert c.exists() and c.read_text() == ""


def test_lazygit_without_config_gets_one_and_loses_it(home):
    h, run = home
    stub(run, "lazygit")
    run("install")
    assert (h / ".config/lazygit/config.yml").exists()
    run("uninstall")
    assert not (h / ".config/lazygit/config.yml").exists()


def test_lazygit_own_config_is_left_alone(home):
    h, run = home
    stub(run, "lazygit")
    c = h / ".config/lazygit/config.yml"
    c.parent.mkdir(parents=True)
    c.write_text("gui:\n  nerdFontsVersion: 3\n")
    log = run("install")
    assert c.read_text() == "gui:\n  nerdFontsVersion: 3\n" and "your own config.yml" in log
    assert re.search(r"lazygit +your own config.yml", run("status"))


def test_lazygit_config_edited_without_the_marker_survives_uninstall(home):
    h, run = home
    stub(run, "lazygit")
    run("install")
    c = h / ".config/lazygit/config.yml"
    c.write_text(c.read_text().split("\n", 1)[1])
    run("uninstall")
    assert c.exists()


def test_no_lazygit_leaves_it_alone(home):
    h, run = home
    stub(run, "lazygit")
    run("install", "--no-lazygit")
    assert not (h / ".config/lazygit").exists()


def test_lazygit_not_installed_is_reported(home):
    h, run = home
    assert re.search(r"lazygit +not installed", run("status"))


# ---------- neovim ----------

def make_lazyvim(h):
    d = h / ".config/nvim/lua/plugins"
    d.mkdir(parents=True)
    (d / "ryoku.lua").write_text("return {}\n")
    return d


def test_nvim_gets_crate_syntax_and_loses_it(home, out):
    h, run = home
    stub(run, "nvim")
    d = make_lazyvim(h)
    run("install")
    assert (d / "crate.lua").read_bytes() == (out / "nvim/crate.lua").read_bytes()
    assert re.search(r"Neovim +Crate syntax", run("status"))
    run("uninstall")
    assert not (d / "crate.lua").exists() and (d / "ryoku.lua").exists()


def test_nvim_own_crate_lua_is_left_alone(home):
    h, run = home
    stub(run, "nvim")
    d = make_lazyvim(h)
    (d / "crate.lua").write_text("return { 'mine' }\n")
    log = run("install")
    assert (d / "crate.lua").read_text() == "return { 'mine' }\n" and "your own" in log
    run("uninstall")
    assert (d / "crate.lua").exists()


def test_nvim_without_a_lazy_config_is_skipped(home):
    h, run = home
    stub(run, "nvim")
    run("install")
    assert not (h / ".config/nvim").exists()
    assert re.search(r"Neovim +installed; no lazy.nvim plugins folder", run("status"))


def test_no_nvim_leaves_it_alone(home):
    h, run = home
    stub(run, "nvim")
    d = make_lazyvim(h)
    run("install", "--no-nvim")
    assert not (d / "crate.lua").exists()


# ---------- GTK ----------

GTK_LINE = '@import url("crate.css"); /* crate-for-ryoku */'


def gtk_with_hook(h, ver="4.0"):
    d = h / f".config/gtk-{ver}"
    d.mkdir(parents=True, exist_ok=True)
    (d / "gtk.css").write_text(':root { --accent-color: #06b6d4; }\n@import url("user.css");\n')
    return d


def test_gtk_install_adds_crate_css_and_takes_it_back(home, out):
    h, run = home
    d4, d3 = gtk_with_hook(h, "4.0"), gtk_with_hook(h, "3.0")
    run("install")
    assert (d4 / "crate.css").read_bytes() == (out / "gtk/crate.css").read_bytes()
    assert (d3 / "crate.css").read_bytes() == (out / "gtk/crate-gtk3.css").read_bytes()
    assert (d4 / "user.css").read_text().splitlines() == [GTK_LINE]
    assert re.search(r"GTK +Crate CSS$", run("status"), re.M)
    run("uninstall")
    for d in (d4, d3):
        assert not (d / "crate.css").exists() and not (d / "user.css").exists()


def test_gtk_keeps_your_own_user_css(home):
    h, run = home
    d4 = gtk_with_hook(h)
    mine = "window { padding: 2px; }\n"
    (d4 / "user.css").write_text(mine)
    run("install")
    run("install")
    assert (d4 / "user.css").read_text() == mine + GTK_LINE + "\n"
    run("uninstall")
    assert (d4 / "user.css").read_text() == mine


def test_gtk_status_says_when_ryoku_does_not_load_user_css(home):
    h, run = home
    d4 = h / ".config/gtk-4.0"
    d4.mkdir(parents=True)
    (d4 / "gtk.css").write_text(":root { --accent-color: #06b6d4; }\n")
    run("install")
    assert "does not load user.css" in run("status")


def test_gtk_uninstall_keeps_an_edited_crate_css(home):
    h, run = home
    d4 = gtk_with_hook(h)
    run("install")
    (d4 / "crate.css").write_text("/* mine now */\n")
    run("uninstall")
    assert (d4 / "crate.css").read_text() == "/* mine now */\n"


def test_gtk_symlinked_user_css_stays_a_symlink(home):
    h, run = home
    d4 = gtk_with_hook(h)
    real = h / "dotfiles/user.css"
    real.parent.mkdir()
    real.write_text("window { padding: 2px; }\n")
    (d4 / "user.css").symlink_to(real)
    run("install")
    run("uninstall")
    assert (d4 / "user.css").is_symlink() and real.read_text() == "window { padding: 2px; }\n"


def test_text_editor_selects_crate_after_a_failed_gsettings_run(home):
    h, run = home
    stub(run, "gnome-text-editor")
    broken = run.bindir / "gsettings"
    broken.write_text("#!/bin/sh\nexit 1\n")
    broken.chmod(0o755)
    run("install")
    state = gsettings_stub(run, h)
    run("install")
    assert state.read_text() == "'crate'"


def test_no_gtk_leaves_it_alone(home):
    h, run = home
    d4 = gtk_with_hook(h)
    run("install", "--no-gtk")
    assert not (d4 / "crate.css").exists() and not (d4 / "user.css").exists()


# ---------- Text Editor (GtkSourceView) ----------

def gsettings_stub(run, h, value="'Adwaita'"):
    state = h / ".gsettings-style-scheme"
    state.write_text(value)
    path = run.bindir / "gsettings"
    path.write_text(f"""#!/bin/sh
case "$1" in
  get) cat "{state}"; echo ;;
  set) printf "'%s'" "$4" > "{state}" ;;
esac
""")
    path.chmod(0o755)
    return state


def test_text_editor_gets_the_crate_scheme_and_its_old_one_back(home, out):
    h, run = home
    stub(run, "gnome-text-editor")
    state = gsettings_stub(run, h)
    run("install")
    xml = h / ".local/share/gtksourceview-5/styles/crate.xml"
    assert xml.read_bytes() == (out / "gtksourceview/crate.xml").read_bytes()
    assert state.read_text() == "'crate'"
    assert re.search(r"Text Editor +Crate scheme selected", run("status"))
    run("uninstall")
    assert state.read_text() == "'Adwaita'" and not xml.exists()


def test_text_editor_scheme_picked_since_stays(home):
    h, run = home
    stub(run, "gnome-text-editor")
    state = gsettings_stub(run, h)
    run("install")
    state.write_text("'kate-dark'")
    log = run("install")
    assert state.read_text() == "'kate-dark'" and "kate-dark" in log
    run("uninstall")
    assert state.read_text() == "'kate-dark'"


def test_gtksourceview_scheme_without_text_editor_selects_nothing(home):
    h, run = home
    state = gsettings_stub(run, h)
    run("install")
    assert (h / ".local/share/gtksourceview-5/styles/crate.xml").exists()
    assert state.read_text() == "'Adwaita'"


def test_edited_scheme_survives_uninstall(home):
    h, run = home
    stub(run, "gnome-text-editor")
    gsettings_stub(run, h)
    run("install")
    xml = h / ".local/share/gtksourceview-5/styles/crate.xml"
    xml.write_text(xml.read_text().replace("Crate's sober", "my"))
    run("uninstall")
    assert xml.exists()


def test_no_gtksourceview_leaves_it_alone(home):
    h, run = home
    stub(run, "gnome-text-editor")
    state = gsettings_stub(run, h)
    run("install", "--no-gtksourceview")
    assert not (h / ".local/share/gtksourceview-5").exists() and state.read_text() == "'Adwaita'"


def test_install_sh_passes_the_app_options_through():
    text = open(os.path.join(ROOT, "package/install.sh")).read()
    assert '--no-obsidian|--no-firefox|--no-zed|--no-lazygit|--no-nvim|--no-gtk|--no-gtksourceview|--firefox-chrome|--firefox-theme|--firefox-profile=*) APP_OPTS+=("$a")' in text
    assert 'bash "$HERE/apps.sh" install' in text
    uninstall = open(os.path.join(ROOT, "package/uninstall.sh")).read()
    assert 'bash "$HERE/apps.sh" uninstall ||' in uninstall
    assert 'bash "$HERE/apps.sh" uninstall --look-only' in uninstall
    assert 'apps.sh" status' in open(os.path.join(ROOT, "bin/crate-for-ryoku")).read()


def test_chrome_manifest_icons_exist_and_the_package_uses_the_same_id():
    m = json.load(open(os.path.join(APPS, "chrome/theme/manifest.json")))
    for rel in m.get("icons", {}).values():
        assert os.path.isfile(os.path.join(APPS, "chrome/theme", rel)), rel
    pkgbuild = open(os.path.join(ROOT, "packaging/aur/crate-for-ryoku/PKGBUILD")).read()
    assert f"_chrome_id={build.chrome_id(m['key'])}" in pkgbuild
    ext = json.load(open(os.path.join(APPS, "chrome/external/crx.json")))
    assert ext == {"external_crx": "/usr/share/crate-for-ryoku/chrome/crate-theme.crx", "external_version": "@VERSION@"}
    assert f"CHROME_CRX={ext['external_crx']}" in open(APPS_SH).read()
    assert not os.path.exists(os.path.join(ROOT, "packaging/aur/crate-for-ryoku-chrome-theme"))
    assert not [f for f in os.listdir(os.path.join(APPS, "chrome/theme")) if f.endswith((".pem", ".pak"))]
