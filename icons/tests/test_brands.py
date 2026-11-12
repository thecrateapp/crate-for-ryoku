"""Brand icons: which apps get a brand mark, and how build_icons.py draws it.

run: python3 -m pytest icons/tests -q
"""
import json
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

import pytest

ICONS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ICONS)

import app_glyphs  # noqa: E402
import build_icons  # noqa: E402
import crateize  # noqa: E402

TABLER = ["brand-firefox", "brand-chrome", "brand-slack", "brand-telegram", "brand-steam",
          "brand-openai", "brand-tidal", "brand-mongodb"]
SIMPLE = ["claude", "thunderbird", "obsidian", "postman", "jetbrains", "phpstorm", "webstorm",
          "onlyoffice", "mpv", "vim", "wine", "nvidia", "qemu", "cmake", "electron", "localsend", "cachyos"]

# every colour a drawn app icon may use: Crate ink, muted, cyan and the tile gradient
PALETTE = {build_icons.FG, build_icons.MUTED, build_icons.CYAN, build_icons.CYAN_HI, "#1a1b23", "#0c0d12"}


# ------------------------------------------------------------------ mapping

@pytest.mark.parametrize("icon,entry,want", [
    ("firefox", "firefox.desktop", ("tabler", "brand-firefox")),
    ("google-chrome", "com.google.Chrome.desktop", ("tabler", "brand-chrome")),
    ("slack", "slack.desktop", ("tabler", "brand-slack")),
    ("org.telegram.desktop", "org.telegram.desktop.desktop", ("tabler", "brand-telegram")),
    ("steam", "steam.desktop", ("tabler", "brand-steam")),
    ("chatgpt", "chatgpt.desktop", ("tabler", "brand-openai")),
    ("tidal-hifi", "tidal-hifi.desktop", ("tabler", "brand-tidal")),
    ("mongodb-compass", "mongodb-compass.desktop", ("tabler", "brand-mongodb")),
    ("claude-desktop", "com.anthropic.Claude.desktop", ("simple-icons", "claude")),
    ("org.mozilla.Thunderbird", "org.mozilla.Thunderbird.desktop", ("simple-icons", "thunderbird")),
    ("CMakeSetup", "cmake-gui.desktop", ("simple-icons", "cmake")),
    ("electron37", "electron37.desktop", ("simple-icons", "electron")),
    ("org.cachyos.hello", "cachyos-hello.desktop", ("simple-icons", "cachyos")),
])
def test_brand_by_icon_name(icon, entry, want):
    assert app_glyphs.brand_for(icon, entry) == want


def test_brand_by_desktop_file_when_the_icon_name_is_unknown():
    assert app_glyphs.brand_for("some-custom-icon", "slack.desktop") == ("tabler", "brand-slack")


@pytest.mark.parametrize("icon,want", [
    ("jetbrains-phpstorm-0a1b2c3d-0000-4000-8000-000000000001", ("simple-icons", "phpstorm")),
    ("jetbrains-webstorm-0a1b2c3d-0000-4000-8000-000000000002", ("simple-icons", "webstorm")),
    ("phpstorm", ("simple-icons", "phpstorm")),
    ("webstorm", ("simple-icons", "webstorm")),
    ("jetbrains-toolbox", ("simple-icons", "jetbrains")),
    ("jetbrains-idea-1234", ("simple-icons", "jetbrains")),
    ("jetbrains-goland", ("simple-icons", "jetbrains")),
])
def test_jetbrains_ides_match_by_prefix(icon, want):
    assert app_glyphs.brand_for(icon, icon + ".desktop") == want


def test_prefixes_do_not_match_inside_a_name():
    assert app_glyphs.brand_for("my-jetbrains-thing", "my-jetbrains-thing.desktop") is None
    assert app_glyphs.brand_for("electron-cash", "electron-cash.desktop") is None
    assert app_glyphs.brand_for("electron", "electron.desktop") == ("simple-icons", "electron")


@pytest.mark.parametrize("icon", ["nvim", "neovim", "io.neovim.nvim"])
def test_neovim_wears_the_vim_mark(icon):
    assert app_glyphs.brand_for(icon, icon + ".desktop") == ("simple-icons", "vim")
    assert app_glyphs.icon_for(icon, icon + ".desktop", []) == ("brand", "simple-icons/vim")


@pytest.mark.parametrize("icon", ["antigravity"])
def test_brands_without_a_free_mark_keep_their_recoloured_icon(icon):
    assert app_glyphs.brand_for(icon, icon + ".desktop") == ("recolor", None)
    assert app_glyphs.icon_for(icon, icon + ".desktop", []) == ("recolor", None)


def test_brands_come_before_solar():
    # firefox also has a Solar glyph in APPS; the brand wins
    assert app_glyphs.icon_for("firefox", "firefox.desktop", ["WebBrowser"]) == ("brand", "tabler/brand-firefox")


def test_generic_apps_keep_solar():
    assert app_glyphs.icon_for("org.gnome.Maps", "org.gnome.Maps.desktop", []) == ("solar", "map")


def test_unknown_apps_fall_back_to_the_category_glyph():
    assert app_glyphs.icon_for("some-browser", "some-browser.desktop", ["Network", "WebBrowser"]) == ("solar", "global")


def test_unknown_apps_without_a_category_get_nothing():
    assert app_glyphs.icon_for("mystery", "mystery.desktop", []) is None


def test_brand_keys_cover_the_rule_and_nothing_else():
    keys = set(app_glyphs.BRAND_KEYS)
    assert keys == {f"tabler/{n}" for n in TABLER} | {f"simple-icons/{n}" for n in SIMPLE}


def test_every_brand_key_is_vendored():
    data = json.load(open(os.path.join(ICONS, "brand-icons.json")))
    assert set(app_glyphs.BRAND_KEYS) <= set(data["icons"])
    for src in ("tabler", "simple-icons"):
        assert re.fullmatch(r"\d+\.\d+\.\d+", data["sources"][src]["version"])  # pinned, exact


def test_only_mit_and_cc0_marks_are_vendored():
    data = json.load(open(os.path.join(ICONS, "brand-icons.json")))
    assert {k.split("/")[0] for k in data["icons"]} == {"tabler", "simple-icons"}
    assert data["sources"]["tabler"]["license"].startswith("MIT")
    assert data["sources"]["simple-icons"]["license"].startswith("CC0")
    assert "simple-icons/neovim" not in data["icons"]  # CC BY-SA: Neovim is recoloured instead


def test_vendored_marks_are_plain_geometry():
    data = json.load(open(os.path.join(ICONS, "brand-icons.json")))
    for key, markup in data["icons"].items():
        ET.fromstring(markup)
        for bad in ("href", "<image", "<script", "<title", "<style", "class="):
            assert bad not in markup, (key, bad)


# ------------------------------------------------------------------ crateize's choice

def test_crateize_draws_a_brand_whatever_the_source():
    assert crateize.pick("firefox", "firefox.desktop", ["WebBrowser"], "/x/firefox.svg") == ("brand", "tabler/brand-firefox")


def test_crateize_recolours_when_the_brand_has_no_free_mark():
    assert crateize.pick("antigravity", "antigravity.desktop", [], "/x/antigravity.png") == ("graded", "/x/antigravity.png")


def test_crateize_recolour_falls_back_to_solar_without_a_source_icon():
    assert crateize.pick("antigravity", "antigravity.desktop", [], None) == ("solar", "code-square")


def test_crateize_graded_style_recolours_brands_too():
    assert crateize.pick("firefox", "firefox.desktop", [], "/x/f.svg", style="graded") == ("graded", "/x/f.svg")


def test_crateize_skips_an_app_with_nothing_to_draw():
    assert crateize.pick("mystery", "mystery.desktop", [], None) is None


# ------------------------------------------------------------------ drawing

def test_split_subpaths_makes_every_start_absolute():
    assert build_icons.split_subpaths("M1 1h2v2h-2zm5 0h2v2h-2z") == ["M1 1h2v2h-2z", "M6 1h2v2h-2z"]
    # without a z the next subpath starts from where the last one ended
    assert build_icons.split_subpaths("M1 1l2 0m1 1l1 1") == ["M1 1l2 0", "M4 2l1 1"]


def test_split_subpaths_unpacks_arc_flags():
    # "011" is large-arc 0, sweep 1, then x = 1
    assert build_icons.split_subpaths("M0 0a1 1 0 011 1m2 0l1 1") == ["M0 0a1 1 0 0 1 1 1", "M3 1l1 1"]


@pytest.mark.skipif(not shutil.which("rsvg-convert"), reason="needs rsvg-convert")
@pytest.mark.parametrize("key", [k for k in app_glyphs.BRAND_KEYS if k.startswith("simple-icons/")])
def test_split_subpaths_redraw_the_same_silhouette(key):
    d = re.search(r'\sd="([^"]*)"', build_icons.BRANDS["icons"][key]).group(1)

    def render(path_d):
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><path d="{path_d}"/></svg>'
        return subprocess.run(["rsvg-convert"], input=svg.encode(), capture_output=True, check=True).stdout

    assert render("".join(build_icons.split_subpaths(d))) == render(d)


@pytest.mark.parametrize("key", sorted(build_icons.BRAND_ACCENT))
def test_accented_brands_draw_their_accent_last_in_cyan(key):
    g = build_icons.brand_glyph(key, 1.5)
    shapes = re.findall(r"<(?:path|circle|rect|ellipse|line|polyline|polygon)\b[^>]*/>", g)
    n = len(build_icons.BRAND_ACCENT[key])
    assert all(build_icons.CYAN_HI in el for el in shapes[-n:])
    assert not any(build_icons.CYAN_HI in el for el in shapes[:-n])


ALL_KEYS = sorted(app_glyphs.BRAND_KEYS)
SIZES = list(build_icons.SIZES)


def _colours(text):
    return {c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}\b", text)}


@pytest.fixture(params=["glyph", "tile"])
def style(request, monkeypatch):
    monkeypatch.setattr(build_icons, "APP_STYLE", request.param)
    return request.param


@pytest.mark.parametrize("key", ALL_KEYS)
@pytest.mark.parametrize("size", SIZES)
def test_brand_svg_is_valid_self_contained_and_in_crate_colours(key, size, style):
    text = build_icons.brand_svg(key, size)
    root = ET.fromstring(text)
    assert root.tag == "{http://www.w3.org/2000/svg}svg"
    assert root.get("viewBox") == "0 0 64 64"
    for bad in ("href", "<image", "<script", "<title", "<style", "currentColor", "class=", "http://www.w3.org/1999"):
        assert bad not in text, bad
    assert not re.search(r"url\((?!#)", text)  # only local gradient references
    assert _colours(text) <= {c.lower() for c in PALETTE}
    assert build_icons.CYAN_HI.lower() in _colours(text) or build_icons.FG.lower() in _colours(text)


def _stroke(text):
    return float(re.search(r'<g fill="none" stroke-width="([\d.]+)"', text).group(1))


@pytest.mark.parametrize("key", [k for k in ALL_KEYS if k.startswith("tabler/")])
@pytest.mark.parametrize("size", SIZES)
def test_line_brands_get_solars_stroke_weight(key, size, style):
    """Device-pixel stroke of a Tabler brand equals the Solar glyph's at the same size."""
    brand = build_icons.brand_svg(key, size)
    solar = build_icons.app_svg("global", size)
    # the brand group is scaled by BRAND_FIT inside the 24 grid; undo that to compare
    fit = build_icons.brand_fit(key)
    assert _stroke(brand) * fit == pytest.approx(_stroke(solar), rel=1e-3)


@pytest.mark.parametrize("key", [k for k in ALL_KEYS if k.startswith("simple-icons/")])
def test_silhouettes_are_filled_not_stroked(key):
    g = build_icons.brand_glyph(key, 1.5)
    assert "stroke" not in g
    assert f'fill="{build_icons.FG}"' in g or f'fill="{build_icons.CYAN_HI}"' in g


@pytest.mark.skipif(not shutil.which("rsvg-convert"), reason="needs rsvg-convert")
@pytest.mark.parametrize("key", ALL_KEYS)
def test_brand_svg_renders(key):
    out = subprocess.run(["rsvg-convert", "-w", "48", "-h", "48"], input=build_icons.brand_svg(key, "scalable").encode(),
                         capture_output=True, check=True).stdout
    assert out[:8] == b"\x89PNG\r\n\x1a\n"


def test_the_theme_ships_brand_icons_but_not_recoloured_ones(tmp_path):
    logo = os.path.join(os.path.dirname(ICONS), "brand", "crate-logo.svg")
    build_icons.main(str(tmp_path), logo)
    apps = tmp_path / "scalable" / "apps"
    assert (apps / "firefox.svg").read_text() == build_icons.brand_svg("tabler/brand-firefox", "scalable")
    assert (apps / "claude-desktop.svg").exists()
    assert not (apps / "antigravity.svg").exists()
    assert (apps / "nvim.svg").read_text() == build_icons.brand_svg("simple-icons/vim", "scalable")
    credits = (tmp_path / "CREDITS").read_text()
    assert "Tabler" in credits and "Simple Icons" in credits and "trademarks" in credits
