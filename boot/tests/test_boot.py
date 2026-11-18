"""run: python3 -m pytest boot/tests -q

The Crate boot themes (Plymouth splash, GRUB menu) as package/build-boot.sh
renders them, and package/boot.sh, which turns them on, against a fake root.
"""
import os
import re
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILD = os.path.join(ROOT, "package", "build-boot.sh")


@pytest.fixture(scope="module")
def out(tmp_path_factory):
    d = tmp_path_factory.mktemp("boot")
    r = subprocess.run(["bash", BUILD, str(d)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    return d


# ---------- Plymouth ----------

def test_plymouth_theme_is_complete(out):
    t = out / "boot/plymouth/crate"
    for name in ("crate.plymouth", "crate.script", "mark.png", "beam-track.png", "beam-fill.png",
                 "bullet.png", "entry.png"):
        assert (t / name).is_file(), name
    conf = (t / "crate.plymouth").read_text()
    assert "ModuleName=script" in conf
    assert "ImageDir=/usr/share/plymouth/themes/crate" in conf
    assert "ScriptFile=/usr/share/plymouth/themes/crate/crate.script" in conf


def test_plymouth_script_registers_its_callbacks_and_crate_colours(out):
    s = (out / "boot/plymouth/crate/crate.script").read_text()
    for fn in ("Plymouth.SetBootProgressFunction", "Plymouth.SetDisplayPasswordFunction",
               "Plymouth.SetDisplayNormalFunction", "Plymouth.SetQuitFunction"):
        assert fn in s, fn
    # pure black: the framebuffer and the greeter are black, anything else leaves a seam
    assert "Window.SetBackgroundTopColor(0.0, 0.0, 0.0);" in s
    assert "Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);" in s


# ---------- GRUB ----------

def grub_theme(out):
    return (out / "boot/grub/crate/theme.txt").read_text()


def test_grub_theme_parses_and_its_files_exist(out):
    t = out / "boot/grub/crate"
    text = grub_theme(out)
    assert re.search(r'^desktop-image: "background.png"$', text, re.M)
    assert re.search(r'^desktop-image-scale-method: "crop"$', text, re.M)
    assert "+ boot_menu {" in text and 'id = "__timeout__"' in text
    for name in ("background.png", "jetbrains-mono-16.pf2", "jetbrains-mono-24.pf2"):
        assert (t / name).is_file(), name
    for part in ("n", "ne", "e", "se", "s", "sw", "w", "nw", "c"):
        assert (t / f"select_{part}.png").is_file(), part
    # the font names the theme asks for are the ones grub-mkfont wrote
    for size in (16, 24):
        assert f"JetBrains Mono Regular {size}".encode() in (t / f"jetbrains-mono-{size}.pf2").read_bytes()
        assert f'"JetBrains Mono Regular {size}"' in text


def test_grub_theme_uses_crate_colours(out):
    allowed = {"#06b6d4", "#999ca0", "#212226", "#0a0a0f", "#f1f5f9"}
    found = {c.lower() for c in re.findall(r"#[0-9a-fA-F]{6}\b", grub_theme(out))}
    assert found and found <= allowed
    assert 'selected_item_color = "#06b6d4"' in grub_theme(out)
