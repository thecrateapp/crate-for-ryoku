#!/usr/bin/env python3
"""Crate Groove, quieted to sit behind a conversation (ZapFast's chat wallpaper).

Groove's background is already Crate black, so nothing is darkened: every mark
(grooves, ticks, the cyan playhead) moves toward the background by KEEP, and
messages read over it the way they read over the plain theme colour.

usage: chat.py GROOVE.(png|webp) OUT.webp [KEEP=0.45]
"""
import sys

import numpy as np
from PIL import Image

BG = (0x0A, 0x0A, 0x0F)


def quiet(rgb, keep):
    """rgb (uint8, HxWx3) with every pixel's distance from BG scaled by keep."""
    bg = np.array(BG, np.float32)
    out = bg + (rgb.astype(np.float32) - bg) * keep
    return np.clip(np.round(out), 0, 255).astype(np.uint8)


if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]
    keep = float(sys.argv[3]) if len(sys.argv) > 3 else 0.45
    rgb = np.asarray(Image.open(src).convert("RGB"))
    Image.fromarray(quiet(rgb, keep)).save(out, "WEBP", lossless=True, quality=100, method=6)
    print(f"wrote {out} (keep {keep})")
