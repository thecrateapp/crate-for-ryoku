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


# ---------- boot.sh apply / revert / status ----------

BOOT_SH = os.path.join(ROOT, "package", "boot.sh")
GRUB_DEFAULT = ("GRUB_DEFAULT=0\nGRUB_TIMEOUT='5'\n"
                "GRUB_CMDLINE_LINUX_DEFAULT='splash loglevel=3'\n"
                "GRUB_THEME='/usr/share/grub/themes/cachyos/theme.txt'\nGRUB_GFXMODE=auto\n")
CRATE_LINE = "GRUB_THEME='/usr/share/grub/themes/crate/theme.txt'"


@pytest.fixture
def sysroot(tmp_path, out):
    root = tmp_path / "root"
    (root / "etc/default").mkdir(parents=True)
    (root / "etc/default/grub").write_text(GRUB_DEFAULT)
    (root / "boot/grub").mkdir(parents=True)
    (root / "boot/grub/grub.cfg").write_text("# old\n")
    bindir = tmp_path / "bin"
    bindir.mkdir()
    log = tmp_path / "calls.log"
    ply = tmp_path / "plymouth-theme"
    ply.write_text("ryoku")
    (bindir / "grub-mkconfig").write_text(f'#!/bin/sh\necho "grub-mkconfig $*" >> "{log}"\n')
    (bindir / "plymouth-set-default-theme").write_text(f"""#!/bin/sh
if [ "$1" = -R ]; then printf '%s' "$2" > "{ply}"; echo "plymouth -R $2" >> "{log}"; else cat "{ply}"; echo; fi
""")
    for f in bindir.iterdir():
        f.chmod(0o755)
    env = dict(os.environ, CRATE_SYSTEM_ROOT=str(root), CRATE_BOOT_THEMES=str(out / "boot"),
               PATH=f"{bindir}:{os.environ['PATH']}")

    def run(*args, ok=True):
        r = subprocess.run(["bash", BOOT_SH, *args], env=env, capture_output=True, text=True)
        if ok:
            assert r.returncode == 0, r.stderr
        return r

    run.root, run.log, run.ply, run.bindir = root, log, ply, bindir
    return run


def test_boot_apply_sets_crate_and_revert_puts_everything_back(sysroot):
    sysroot("apply")
    grub = (sysroot.root / "etc/default/grub").read_text()
    assert CRATE_LINE in grub and "cachyos" not in grub
    assert sysroot.ply.read_text() == "crate"
    assert (sysroot.root / "usr/share/grub/themes/crate/theme.txt").is_file()
    assert (sysroot.root / "usr/share/plymouth/themes/crate/crate.script").is_file()
    assert "grub-mkconfig -o" in sysroot.log.read_text()
    assert (sysroot.root / "var/lib/crate-for-ryoku/grub.default.before-crate").read_text() == GRUB_DEFAULT
    st = sysroot("status").stdout
    assert re.search(r"Plymouth +crate", st) and re.search(r"GRUB +Crate", st)
    sysroot("revert")
    assert (sysroot.root / "etc/default/grub").read_text() == GRUB_DEFAULT
    assert sysroot.ply.read_text() == "ryoku"


def test_boot_apply_twice_keeps_the_first_record(sysroot):
    sysroot("apply")
    sysroot("apply")
    sysroot("revert")
    assert (sysroot.root / "etc/default/grub").read_text() == GRUB_DEFAULT
    assert sysroot.ply.read_text() == "ryoku"


def test_boot_without_a_grub_theme_line_adds_and_removes_ours(sysroot):
    src = "GRUB_DEFAULT=0\n#GRUB_THEME=\"/path/theme.txt\"\nGRUB_GFXMODE=auto\n"
    (sysroot.root / "etc/default/grub").write_text(src)
    sysroot("apply")
    assert CRATE_LINE in (sysroot.root / "etc/default/grub").read_text()
    sysroot("revert")
    assert (sysroot.root / "etc/default/grub").read_text() == src


def test_boot_failing_grub_mkconfig_stops_and_says_how_to_finish(sysroot):
    (sysroot.bindir / "grub-mkconfig").write_text("#!/bin/sh\nexit 1\n")
    r = sysroot("apply", ok=False)
    assert r.returncode != 0 and "grub-mkconfig" in r.stderr and "boot revert" in r.stderr
    assert sysroot.ply.read_text() == "ryoku"  # stopped before the initramfs


def test_boot_revert_with_nothing_applied_says_so(sysroot):
    r = sysroot("revert", ok=False)
    assert r.returncode != 0 and "nothing to revert" in r.stderr


def test_boot_status_needs_no_writes(sysroot):
    before = sorted(p.relative_to(sysroot.root) for p in sysroot.root.rglob("*"))
    st = sysroot("status").stdout
    assert re.search(r"Plymouth +ryoku", st) and re.search(r"GRUB +/usr/share/grub/themes/cachyos", st)
    assert sorted(p.relative_to(sysroot.root) for p in sysroot.root.rglob("*")) == before


def test_the_package_build_renders_the_boot_themes():
    build = open(os.path.join(ROOT, "package", "build.sh")).read()
    assert 'bash "$SRC/package/build-boot.sh" "$OUT"' in build
