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


# ---------- rEFInd ----------

def test_refind_theme_is_complete(out):
    t = out / "boot/refind/crate"
    for name in ("theme.conf", "banner.png", "selection_big.png", "selection_small.png", "font.png"):
        assert (t / name).is_file(), name
    for icon in ("os_cachyos", "os_win", "func_shutdown", "func_reset", "func_firmware", "func_about", "func_exit"):
        assert (t / f"icons/{icon}.png").is_file(), icon
    conf = (t / "theme.conf").read_text()
    for line in ("banner themes/crate/banner.png", "banner_scale fillscreen", "font themes/crate/font.png",
                 "icons_dir themes/crate/icons", "hideui hints,arrows,badges"):
        assert re.search(rf"^{re.escape(line)}$", conf, re.M), line


def test_refind_banner_and_font_are_crate(out):
    from PIL import Image
    t = out / "boot/refind/crate"
    banner = Image.open(t / "banner.png").convert("RGB")
    assert banner.size == (3840, 2400)
    assert banner.getpixel((10, 10)) == (10, 10, 15)          # the canvas
    font = Image.open(t / "font.png").convert("RGBA")
    assert font.width % 96 == 0                                # rEFInd: 96 equal cells, ASCII 32..127
    ink = [px for px in font.getdata() if px[3] > 128]
    assert ink and all(px[:3] == (0, 0, 0) for px in ink)      # black glyphs: rEFInd inverts them on dark
    cell = font.width // 96
    a_lower = font.crop((cell * (ord("a") - 32), 0, cell * (ord("a") - 31), font.height)).tobytes()
    a_upper = font.crop((cell * (ord("A") - 32), 0, cell * (ord("A") - 31), font.height)).tobytes()
    assert a_lower == a_upper                                  # caps everywhere


# ---------- boot.sh apply / revert / status ----------

BOOT_SH = os.path.join(ROOT, "package", "boot.sh")
GRUB_DEFAULT = ("GRUB_DEFAULT=0\nGRUB_TIMEOUT='5'\n"
                "GRUB_CMDLINE_LINUX_DEFAULT='splash loglevel=3'\nGRUB_TIMEOUT_STYLE=menu\n"
                "GRUB_THEME='/usr/share/grub/themes/cachyos/theme.txt'\n")


@pytest.fixture
def sysroot(tmp_path, out):
    root = tmp_path / "root"
    (root / "etc/default").mkdir(parents=True)
    (root / "etc/default/grub").write_text(GRUB_DEFAULT)
    (root / "boot/grub").mkdir(parents=True)
    (root / "boot/grub/grub.cfg").write_text("# old\n")
    for loader in ("EFI/cachyos/grubx64.efi", "EFI/Microsoft/Boot/bootmgfw.efi"):
        (root / "boot/efi" / loader).parent.mkdir(parents=True, exist_ok=True)
        (root / "boot/efi" / loader).write_text("efi")
    bindir = tmp_path / "bin"
    bindir.mkdir()
    log, ply, order = tmp_path / "calls.log", tmp_path / "plymouth-theme", tmp_path / "bootorder"
    ply.write_text("ryoku")
    order.write_text("0007,0005,0000")
    stubs = {
        "grub-mkconfig": f'echo "grub-mkconfig $*" >> "{log}"',
        "plymouth-set-default-theme": f'if [ "$1" = -R ]; then printf "%s" "$2" > "{ply}"; echo "plymouth -R $2" >> "{log}"; else cat "{ply}"; echo; fi',
        "refind-install": (f'mkdir -p "{root}/boot/efi/EFI/refind" && echo efi > "{root}/boot/efi/EFI/refind/refind_x64.efi" '
                           f'&& echo "# sample" > "{root}/boot/efi/EFI/refind/refind.conf" && printf "%s" "0009,$(cat "{order}")" > "{order}" '
                           f'&& echo "refind-install" >> "{log}"'),
        "efibootmgr": (f'if [ "$1" = -o ]; then printf "%s" "$2" > "{order}"; echo "efibootmgr -o $2" >> "{log}"; '
                       f'else echo "BootCurrent: 0007"; echo "BootOrder: $(cat "{order}")"; '
                       f'echo "Boot0007* cachyos"; echo "Boot0009* rEFInd Boot Manager"; fi'),
    }
    for name, body in stubs.items():
        (bindir / name).write_text("#!/bin/sh\n" + body + "\n")
        (bindir / name).chmod(0o755)
    env = dict(os.environ, CRATE_SYSTEM_ROOT=str(root), CRATE_BOOT_THEMES=str(out / "boot"),
               PATH=f"{bindir}:{os.environ['PATH']}")

    def run(*args, ok=True):
        r = subprocess.run(["bash", BOOT_SH, *args], env=env, capture_output=True, text=True)
        if ok:
            assert r.returncode == 0, r.stderr
        return r

    run.root, run.log, run.ply, run.order, run.bindir = root, log, ply, order, bindir
    return run


def refind_conf(run):
    return (run.root / "boot/efi/EFI/refind/refind.conf").read_text()


def test_boot_apply_puts_crate_refind_first_and_revert_puts_everything_back(sysroot):
    out = sysroot("apply").stdout
    assert "running: refind-install" in out and "running: plymouth-set-default-theme -R crate" in out
    conf = refind_conf(sysroot)
    assert "include themes/crate/theme.conf" in conf and "scanfor manual" in conf
    assert "loader \\EFI\\cachyos\\grubx64.efi" in conf and "loader \\EFI\\Microsoft\\Boot\\bootmgfw.efi" in conf
    assert (sysroot.root / "boot/efi/EFI/refind/themes/crate/banner.png").is_file()
    assert sysroot.order.read_text().startswith("0009,")
    grub = (sysroot.root / "etc/default/grub").read_text()
    assert "GRUB_TIMEOUT=0\n" in grub and "GRUB_TIMEOUT_STYLE=hidden\n" in grub
    assert sysroot.ply.read_text() == "crate"
    st = sysroot("status").stdout
    assert re.search(r"rEFInd +first, Crate theme", st) and re.search(r"Plymouth +crate", st)
    sysroot("revert")
    assert (sysroot.root / "etc/default/grub").read_text() == GRUB_DEFAULT
    assert sysroot.order.read_text() == "0007,0005,0000"
    assert sysroot.ply.read_text() == "ryoku"
    assert refind_conf(sysroot) == "# sample\n"


def test_boot_apply_twice_keeps_the_first_record(sysroot):
    sysroot("apply")
    sysroot("apply")
    sysroot("revert")
    assert (sysroot.root / "etc/default/grub").read_text() == GRUB_DEFAULT
    assert sysroot.order.read_text() == "0007,0005,0000"


def test_boot_without_windows_writes_no_windows_stanza(sysroot):
    (sysroot.root / "boot/efi/EFI/Microsoft/Boot/bootmgfw.efi").unlink()
    sysroot("apply")
    assert "bootmgfw" not in refind_conf(sysroot)


def test_boot_without_refind_install_stops_before_any_change(sysroot):
    (sysroot.bindir / "refind-install").unlink()
    env_path = f"{sysroot.bindir}:/usr/local/sbin:/usr/sbin:/sbin"
    r = subprocess.run(["bash", BOOT_SH, "apply"], capture_output=True, text=True,
                       env=dict(os.environ, CRATE_SYSTEM_ROOT=str(sysroot.root), PATH=env_path + ":/usr/bin:/bin"))
    if r.returncode == 0:
        pytest.skip("this machine has refind-install on PATH")
    assert "refind" in r.stderr and (sysroot.root / "etc/default/grub").read_text() == GRUB_DEFAULT


def test_boot_failing_grub_mkconfig_stops_and_says_how_to_finish(sysroot):
    (sysroot.bindir / "grub-mkconfig").write_text("#!/bin/sh\nexit 1\n")
    r = sysroot("apply", ok=False)
    assert r.returncode != 0 and "grub-mkconfig" in r.stderr and "boot revert" in r.stderr
    assert sysroot.ply.read_text() == "ryoku"


def test_boot_revert_with_nothing_applied_says_so(sysroot):
    r = sysroot("revert", ok=False)
    assert r.returncode != 0 and "nothing to revert" in r.stderr


def test_boot_status_needs_no_writes(sysroot):
    before = sorted(p.relative_to(sysroot.root) for p in sysroot.root.rglob("*"))
    st = sysroot("status").stdout
    assert re.search(r"Plymouth +ryoku", st) and re.search(r"rEFInd +not installed", st)
    assert sorted(p.relative_to(sysroot.root) for p in sysroot.root.rglob("*")) == before


def test_the_package_build_renders_the_boot_themes():
    build = open(os.path.join(ROOT, "package", "build.sh")).read()
    assert 'bash "$SRC/package/build-boot.sh" "$OUT"' in build
