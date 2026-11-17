"""run: python3 -m pytest apps/tests -q

package/zed_settings.py edits Zed's JSONC settings.json in place: only the
theme value it must, comments and formatting kept, and back again.
"""
import os
import subprocess
import sys

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ZS = os.path.join(ROOT, "package", "zed_settings.py")
sys.path.insert(0, os.path.dirname(ZS))

import zed_settings as zs  # noqa: E402

DEFAULT = ('// Zed settings\n//\n// see docs\n{\n  "ui_font_size": 16,\n  "theme": {\n'
           '    "mode": "system",\n    "light": "One Light",\n    "dark": "One Dark"\n  }\n}\n')


def test_select_changes_only_the_dark_slot(tmp_path):
    p = tmp_path / "settings.json"
    p.write_text(DEFAULT)
    assert zs.select(str(p), "Crate") == ("dark", '"One Dark"')
    assert p.read_text() == DEFAULT.replace('"dark": "One Dark"', '"dark": "Crate"')


def test_restore_puts_the_old_dark_back(tmp_path):
    p = tmp_path / "settings.json"
    p.write_text(DEFAULT)
    mode, prev = zs.select(str(p), "Crate")
    assert zs.restore(str(p), "Crate", mode, prev) is True
    assert p.read_text() == DEFAULT


def test_restore_keeps_a_theme_picked_since(tmp_path):
    p = tmp_path / "settings.json"
    p.write_text(DEFAULT)
    mode, prev = zs.select(str(p), "Crate")
    p.write_text(p.read_text().replace('"Crate"', '"Gruvbox"'))
    assert zs.restore(str(p), "Crate", mode, prev) is False
    assert '"Gruvbox"' in p.read_text()


def test_string_theme_with_trailing_comma(tmp_path):
    p = tmp_path / "settings.json"
    p.write_text('{ "theme": "Ayu Dark", }')
    assert zs.select(str(p), "Crate") == ("string", '"Ayu Dark"')
    assert zs.current(str(p)) == "Crate"
    zs.restore(str(p), "Crate", "string", '"Ayu Dark"')
    assert p.read_text() == '{ "theme": "Ayu Dark", }'


def test_missing_key_is_added_and_removed(tmp_path):
    src = '{\n  /* mine */ "vim_mode": true\n}\n'
    p = tmp_path / "settings.json"
    p.write_text(src)
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
    p = tmp_path / "settings.json"
    p.write_text(src)
    zs.select(str(p), "Crate")
    assert p.read_text() == src.replace('"dark": "One Dark"', '"dark": "Crate"')


def test_invalid_jsonc_is_left_untouched(tmp_path):
    p = tmp_path / "settings.json"
    p.write_text('{ "theme": ')
    with pytest.raises(ValueError):
        zs.select(str(p), "Crate")
    assert p.read_text() == '{ "theme": '


def test_cli_select_prints_mode_and_previous(tmp_path):
    p = tmp_path / "settings.json"
    p.write_text(DEFAULT)
    r = subprocess.run([sys.executable, ZS, "select", str(p), "Crate"], capture_output=True, text=True)
    assert r.returncode == 0 and r.stdout == 'dark\t"One Dark"\n'


def test_theme_object_without_dark_gets_one_and_loses_it(tmp_path):
    src = '{ "theme": { "mode": "dark" } }'
    p = tmp_path / "settings.json"
    p.write_text(src)
    mode, prev = zs.select(str(p), "Crate")
    assert (mode, prev) == ("added-dark", "-") and zs.current(str(p)) == "Crate"
    assert zs.restore(str(p), "Crate", mode, prev) is True
    assert p.read_text() == src
