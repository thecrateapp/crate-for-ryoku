"""run: python3 -m pytest wallpaper/tests -q"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import chat  # noqa: E402


def test_the_background_stays_crate_black():
    bg = np.zeros((2, 2, 3), np.uint8) + np.array(chat.BG, np.uint8)
    assert (chat.quiet(bg, 0.5) == bg).all()


def test_marks_move_toward_the_background_by_keep():
    px = np.array([[[0x67, 0xE8, 0xF9]]], np.uint8)  # the playhead's cyan
    out = chat.quiet(px, 0.5).astype(int)
    want = np.round(np.array(chat.BG) + (np.array([0x67, 0xE8, 0xF9]) - np.array(chat.BG)) * 0.5)
    assert (out[0, 0] == want).all()
