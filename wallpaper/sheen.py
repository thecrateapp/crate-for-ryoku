#!/usr/bin/env python3
"""Crate Sheen: the second wallpaper of the Crate set, in the line of Crate Groove.

The record fills more of the frame and catches light: the anisotropic sheen
vinyl throws under a light source, two bright lobes along a diameter. The
playhead on the fourth track is the one cyan element; an echo one track in is
its next pass, faint.

Same rules as groove.py: Crate v3 tokens, 1 / 1.5 / 2.25 CSS px strokes at 1.6667,
one active element in cyan, the top band and one side left empty, no text.

usage: sheen.py WIDTH HEIGHT OUT.png
"""
import math
import sys

import cairo
import numpy as np
from PIL import Image, ImageFilter

BG = np.array((0x0A, 0x0A, 0x0F), np.float32) / 255.0
FG = (0xF1 / 255, 0xF5 / 255, 0xF9 / 255)
CYAN = (0x06 / 255, 0xB6 / 255, 0xD4 / 255)
CYAN_HI = (0x67 / 255, 0xE8 / 255, 0xF9 / 255)
DPR = 1.6667
HAIR, LINE, ACTIVE, DOWNBEAT = 1.0 * DPR, 1.5 * DPR, 2.25 * DPR, 1.75 * DPR


# ----------------------------------------------------------------- plumbing
def layer(W, H):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    c = cairo.Context(s)
    c.set_antialias(cairo.ANTIALIAS_BEST)
    c.set_source_rgba(1, 1, 1, 1)
    return s, c


def alpha_of(surf):
    surf.flush()
    W, H = surf.get_width(), surf.get_height()
    a = np.ndarray((H, surf.get_stride() // 4, 4), np.uint8, surf.get_data())[:, :W, 3]
    return a.astype(np.float32) / 255.0


def blur(a, radius):
    img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), np.float32) / 255.0


def over(dst, color, alpha):
    c = np.array(color, np.float32).reshape(1, 1, 3)
    a = np.clip(alpha, 0, 1)[..., None]
    return dst * (1 - a) + c * a


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def finish(img, out, seed):
    rng = np.random.default_rng(seed)
    H, W, _ = img.shape
    img = img * 255.0
    img += rng.normal(0.0, 1.0, (H, W, 1)).astype(np.float32) * (255 * 0.045 * 0.18)
    img += rng.uniform(-0.5, 0.5, (H, W, 3)).astype(np.float32)
    Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8)).save(out, optimize=True)


def canvas(W, H):
    img = np.empty((H, W, 3), np.float32)
    img[:] = BG
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    return img, xs, ys


def lift(img, xs, ys, x, y, radius, strength):
    d = np.hypot(xs - x, ys - y) / radius
    return over(img, CYAN, strength * np.exp(-3.2 * d * d))


def arc(ctx, cx, cy, r, t0, t1):
    ctx.new_sub_path()
    ctx.arc(cx, cy, r, math.radians(t0 - 90), math.radians(t1 - 90))


def pt(cx, cy, r, t):
    a = math.radians(t - 90)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def polar(xs, ys, cx, cy):
    return np.degrees(np.arctan2(xs - cx, -(ys - cy)))


def record(W, H, cx, cy, r_min, r_max, tracks, pitch, t0=-80, t1=100):
    """Groove and track-edge coverage layers for one record."""
    gs, g = layer(W, H)
    es, e = layer(W, H)
    g.set_line_width(HAIR)
    e.set_line_width(HAIR)
    band = r_max - r_min
    for a, b in tracks:
        r0, r1 = r_min + band * a, r_min + band * b
        for i in range(int((r1 - r0) / pitch) + 1):
            arc(g, cx, cy, r0 + i * pitch, t0, t1)
            g.stroke()
        for f in (a, b):
            arc(e, cx, cy, r_min + band * f, t0, t1)
            e.stroke()
    return alpha_of(gs), alpha_of(es)


def playhead(img, W, H, k, cx, cy, r, ta, tb, theta, glow_strength=0.22, head=True, color=CYAN_HI):
    trail = 0.2 + 0.8 * np.clip((theta - ta) / (tb - ta), 0, 1)
    s, c = layer(W, H)
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    c.set_line_width(10 * DPR)
    arc(c, cx, cy, r, ta, tb)
    c.stroke()
    hx, hy = pt(cx, cy, r, tb)
    if head:
        c.arc(hx, hy, 22 * k, 0, 2 * math.pi)
        c.fill()
    if glow_strength > 0:
        img = over(img, color, blur(alpha_of(s), 16 * k) * glow_strength * trail)
    s, c = layer(W, H)
    c.set_line_cap(cairo.LINE_CAP_ROUND)
    c.set_line_width(ACTIVE)
    arc(c, cx, cy, r, ta, tb)
    c.stroke()
    img = over(img, color, alpha_of(s) * trail * (1.0 if head else 0.35))
    if head:
        s, c = layer(W, H)
        c.arc(hx, hy, 4.6 * k, 0, 2 * math.pi)
        c.fill()
        img = over(img, color, alpha_of(s))
    return img


def beat_ticks(W, H, k, cx, cy, r, t0, t1, step, inward=True):
    s, c = layer(W, H)
    t, i = t0, 0
    while t <= t1:
        down = i % 4 == 0
        ln = (32 if down else 16) * k
        c.set_line_width(DOWNBEAT if down else HAIR)
        c.set_source_rgba(1, 1, 1, 1.0 if down else 0.55)
        c.move_to(*pt(cx, cy, r, t))
        c.line_to(*pt(cx, cy, r - ln if inward else r + ln, t))
        c.stroke()
        t += step
        i += 1
    return alpha_of(s)


# ------------------------------------------------------------------- frames
def sheen(W, H):
    """The record fills more of the frame and catches light."""
    k = H / 2160.0
    img, xs, ys = canvas(W, H)
    cx, cy = W * 0.76, H * 1.12
    r_max, r_min = cy - 0.13 * H, 0.30 * H
    tracks = [(0.00, 0.10), (0.13, 0.31), (0.34, 0.47), (0.50, 0.72), (0.75, 0.88), (0.91, 1.00)]
    theta = polar(xs, ys, cx, cy)
    rr = np.hypot(xs - cx, ys - cy)
    sector = smooth(-74, -48, theta) * (1 - smooth(78, 96, theta))
    # anisotropic sheen: two bright lobes along a diameter, as a light source does on vinyl
    lobe = np.exp(-((theta - 24) / 11) ** 2) + 0.55 * np.exp(-((theta + 38) / 14) ** 2)
    disc = smooth(r_min - 40 * k, r_min, rr) * (1 - smooth(r_max, r_max + 40 * k, rr))
    img = over(img, FG, 0.018 * lobe * disc * sector)
    r_play = r_min + (r_max - r_min) * tracks[3][1]
    hx, hy = pt(cx, cy, r_play, 6)
    img = lift(img, xs, ys, hx, hy, 0.7 * H, 0.06)
    grooves, edges = record(W, H, cx, cy, r_min, r_max, tracks, 11 * k)
    img = over(img, FG, grooves * (0.05 + 0.10 * lobe) * sector)
    img = over(img, FG, edges * (0.12 + 0.12 * lobe) * sector)
    img = over(img, FG, beat_ticks(W, H, k, cx, cy, r_play - 12 * k, -46, 40, 1.4) * 0.26 * sector)
    on = beat_ticks(W, H, k, cx, cy, r_play - 12 * k, -16.8, 6, 1.4)
    img = over(img, CYAN_HI, on * 0.6 * ((theta >= -17) & (theta <= 6.2)))
    # an echo of the head one track in: the next pass, faint
    img = playhead(img, W, H, k, cx, cy, r_min + (r_max - r_min) * tracks[2][1], -4, 2, theta,
                   glow_strength=0.0, head=False, color=CYAN)
    img = playhead(img, W, H, k, cx, cy, r_play, -17, 6, theta, glow_strength=0.32)
    return img



if __name__ == "__main__":
    w, h, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    finish(sheen(w, h), out, 21)
    print(f"wrote {out} ({w}x{h})")
