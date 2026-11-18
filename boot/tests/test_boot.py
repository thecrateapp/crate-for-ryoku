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
