#!/usr/bin/env python3
"""Crate Groove: the wallpaper for the Ryoku x Crate v3 rice.

A record surface seen from its edge. The groove centre sits below the bottom
right corner, so only one sector of faint concentric hairlines enters the frame.
A single cyan segment, the playhead, is the only active element. The top band
(under the bar) and the left half stay empty so tiled windows and an empty
workspace both have room to rest.

Tokens are Crate v3 values (app/web/src/styles/tokens.css, app/shared/ui/tokens/themes.css):
  bg #0a0a0f, fg #f1f5f9, hairline fg at .10, cyan #06b6d4, cyan-hi #67e8f9.
Stroke widths are the web figure widths (1 / 1.5 / 2.25 CSS px) multiplied by
1.6667, the scale of a 3840-wide panel, so a hairline here is a hairline on screen.

usage: groove.py WIDTH HEIGHT OUT.png
"""
import math
import sys

import cairo
import numpy as np
from PIL import Image, ImageFilter

BG = (0x0A, 0x0A, 0x0F)  # 0..255
FG = (0xF1 / 255, 0xF5 / 255, 0xF9 / 255)
CYAN = (0x06 / 255, 0xB6 / 255, 0xD4 / 255)
CYAN_HI = (0x67 / 255, 0xE8 / 255, 0xF9 / 255)

DPR = 1.6667  # CSS px -> device px on a 3840-wide panel
HAIR = 1.0 * DPR
ACTIVE = 2.25 * DPR
DOWNBEAT = 1.75 * DPR


def arc(ctx, cx, cy, r, t0, t1):
    # theta measured from straight up, clockwise positive
    ctx.new_sub_path()
    ctx.arc(cx, cy, r, math.radians(t0 - 90), math.radians(t1 - 90))


def layer(W, H):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf)
    ctx.set_antialias(cairo.ANTIALIAS_BEST)
    return surf, ctx


def alpha_of(surf):
    """Coverage of a white-on-transparent cairo layer as float32 in 0..1."""
    surf.flush()
    W, H = surf.get_width(), surf.get_height()
    a = np.ndarray((H, surf.get_stride() // 4, 4), np.uint8, surf.get_data())[:, :W, 3]
    return a.astype(np.float32) / 255.0


def over(dst, color, alpha):
    c = np.array(color, np.float32).reshape(1, 1, 3)
    a = alpha[..., None]
    return dst * (1 - a) + c * a


def point(cx, cy, r, theta):
    th = math.radians(theta - 90)
    return cx + r * math.cos(th), cy + r * math.sin(th)


def render(W, H, out):
    k = H / 2160.0
    cx, cy = W * 0.80, H * 1.24
    top_rest = 0.20 * H  # nothing above this line: the bar's rest band
    r_max = cy - top_rest
    r_min = 0.46 * H
    band = r_max - r_min
    # tracks: (start, end) as fractions of the groove band, inner -> outer.
    # the gaps between them are the lead-in silence between songs.
    tracks = [(0.00, 0.16), (0.20, 0.43), (0.47, 0.58), (0.62, 0.86), (0.90, 1.00)]
    groove_pitch = 15 * k
    active_track = 3
    r_active = r_min + band * tracks[active_track][0]
    play_t0, play_t1 = -9.0, 5.0
    px, py = point(cx, cy, r_active, play_t1)

    # per-pixel polar coordinates around the groove centre
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    dx, dy = xs - cx, ys - cy
    theta = np.degrees(np.arctan2(dx, -dy))  # 0 = straight up, clockwise positive
    ss = lambda e0, e1, x: (lambda t: t * t * (3 - 2 * t))(np.clip((x - e0) / (e1 - e0), 0, 1))
    sector = ss(-64, -38, theta) * (1 - ss(70, 92, theta))

    img = np.empty((H, W, 3), np.float32)
    img[:] = np.array(BG, np.float32) / 255.0

    # a very low lift around the playhead, so the active corner is not flat
    d = np.hypot(xs - px, ys - py) / (0.62 * H)
    lift = 0.045 * np.exp(-3.2 * d * d)
    img = over(img, CYAN, lift.astype(np.float32))

    # grooves: faint, every ring a hairline
    surf, ctx = layer(W, H)
    ctx.set_source_rgba(1, 1, 1, 1)
    ctx.set_line_width(HAIR)
    for (a, b) in tracks:
        r0, r1 = r_min + band * a, r_min + band * b
        for i in range(int((r1 - r0) / groove_pitch) + 1):
            arc(ctx, cx, cy, r0 + i * groove_pitch, -75, 100)
            ctx.stroke()
    img = over(img, FG, alpha_of(surf) * 0.045 * sector)

    # structure: the edge of every track, the one layer meant to be read
    surf, ctx = layer(W, H)
    ctx.set_source_rgba(1, 1, 1, 1)
    ctx.set_line_width(HAIR)
    for (a, b) in tracks:
        for f in (a, b):
            arc(ctx, cx, cy, r_min + band * f, -75, 100)
            ctx.stroke()
    img = over(img, FG, alpha_of(surf) * 0.10 * sector)

    # beat ticks just inside the active track edge; the downbeat is heavier
    tick_r = r_active - 10 * k
    beat, t, i = 1.6, -40.0, 0
    off, off_ctx = layer(W, H)
    on, on_ctx = layer(W, H)
    while t <= 34.0:
        downbeat = i % 4 == 0
        length = (30 if downbeat else 16) * k
        in_play = play_t0 <= t <= play_t1
        c = on_ctx if in_play else off_ctx
        c.set_source_rgba(1, 1, 1, 1 if in_play else (1.0 if downbeat else 0.57))
        c.set_line_width(DOWNBEAT if downbeat else HAIR)
        c.move_to(*point(cx, cy, tick_r, t))
        c.line_to(*point(cx, cy, tick_r - length, t))
        c.stroke()
        t += beat
        i += 1
    img = over(img, FG, alpha_of(off) * 0.28 * sector)
    img = over(img, CYAN_HI, alpha_of(on) * 0.55)

    # the playhead: trail that brightens toward the head, glow underlay, stylus dot
    trail = 0.25 + 0.75 * np.clip((theta - play_t0) / (play_t1 - play_t0), 0, 1)
    surf, ctx = layer(W, H)
    ctx.set_source_rgba(1, 1, 1, 1)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_width(9 * DPR)
    arc(ctx, cx, cy, r_active, play_t0, play_t1)
    ctx.stroke()
    ctx.arc(px, py, 18 * k, 0, 2 * math.pi)
    ctx.fill()
    glow = Image.fromarray((alpha_of(surf) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14 * k))
    img = over(img, CYAN_HI, np.asarray(glow, np.float32) / 255.0 * 0.20 * trail)

    surf, ctx = layer(W, H)
    ctx.set_source_rgba(1, 1, 1, 1)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_line_width(ACTIVE)
    arc(ctx, cx, cy, r_active, play_t0, play_t1)
    ctx.stroke()
    img = over(img, CYAN_HI, alpha_of(surf) * trail)
    surf, ctx = layer(W, H)
    ctx.set_source_rgba(1, 1, 1, 1)
    ctx.arc(px, py, 4.2 * k, 0, 2 * math.pi)
    ctx.fill()
    img = over(img, CYAN_HI, alpha_of(surf))

    # grain at a fraction of the website's .045, plus dither: quantize once, no banding
    rng = np.random.default_rng(132)
    img = img * 255.0
    img += rng.normal(0.0, 1.0, (H, W, 1)).astype(np.float32) * (255 * 0.045 * 0.18)
    img += rng.uniform(-0.5, 0.5, (H, W, 3)).astype(np.float32)
    Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8)).save(out, optimize=True)
    print(f"wrote {out} ({W}x{H})  playhead at {px:.0f},{py:.0f}")


if __name__ == "__main__":
    w, h, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    render(w, h, out)
