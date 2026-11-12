#!/usr/bin/env python3
"""Crate wallpaper series for the Ryoku rice: four frames in the line of Crate Groove.

  sheen    the record, larger, with the anisotropic sheen vinyl throws under light
  horizon  a waveform horizon: the played part cyan, a playhead, the beat grid below
  handoff  two decks overlapping; the playhead passes from one record to the other
  macro    a close-up of grooves modulated by the audio, the stylus in cyan

Same rules as groove.py: Crate v3 tokens, 1 / 1.5 / 2.25 CSS px strokes at 1.6667,
one active element in cyan, the top band and one side left empty, no text.

usage: series.py NAME WIDTH HEIGHT OUT.png      (NAME = sheen|horizon|handoff|macro)
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


def horizon(W, H):
    """A waveform laid as a horizon; the part already played is cyan."""
    k = H / 2160.0
    img, xs, ys = canvas(W, H)
    base = 0.72 * H
    x0, x1 = 0.05 * W, 0.95 * W
    play_x = x0 + (x1 - x0) * 0.63
    img = lift(img, xs, ys, play_x, base - 0.08 * H, 0.55 * H, 0.055)
    rng = np.random.default_rng(7)
    step = 6.5 * k
    n = int((x1 - x0) / step)
    t = np.linspace(0, 1, n)
    # an arrangement: intro, build, drop, break, second drop, outro
    env = (0.22 + 0.25 * smooth(0.06, 0.22, t) + 0.45 * smooth(0.30, 0.33, t)
           - 0.38 * smooth(0.55, 0.57, t) + 0.50 * smooth(0.70, 0.72, t) - 0.55 * smooth(0.92, 0.99, t))
    detail = np.abs(np.convolve(rng.normal(0, 1, n), np.ones(5) / 5, mode="same"))
    beat = 0.75 + 0.25 * (np.cos(np.arange(n) * 2 * np.pi / 16) > 0.6)
    amp = np.clip(env * (0.55 + 0.6 * detail) * beat, 0.02, 1.2) * 0.20 * H
    off, oc = layer(W, H)
    played, pc = layer(W, H)
    refl, rc = layer(W, H)
    for i in range(n):
        x = x0 + i * step
        c = pc if x <= play_x else oc
        c.set_line_width(HAIR)
        c.move_to(x, base)
        c.line_to(x, base - amp[i])
        c.stroke()
        rc.set_line_width(HAIR)
        rc.move_to(x, base + 6 * k)
        rc.line_to(x, base + 6 * k + amp[i] * 0.32)
        rc.stroke()
    fade_x = smooth(x0 - 1, x0 + 0.08 * W, xs) * (1 - smooth(x1 - 0.08 * W, x1 + 1, xs))
    reflection_fade = 1 - smooth(base, base + 0.09 * H, ys)
    img = over(img, FG, alpha_of(off) * 0.16 * fade_x)
    img = over(img, FG, alpha_of(refl) * 0.06 * fade_x * reflection_fade)
    pa = alpha_of(played)
    ramp = 0.10 + 0.90 * smooth(play_x - 0.30 * W, play_x, xs) ** 2
    img = over(img, FG, pa * 0.16 * fade_x * (1 - ramp))
    img = over(img, CYAN_HI, blur(pa, 10 * k) * 0.30 * ramp * fade_x)
    img = over(img, CYAN_HI, pa * 0.85 * ramp * fade_x)
    # horizon rule and the beat grid under it
    s, c = layer(W, H)
    c.set_line_width(HAIR)
    c.move_to(0, base + 0.5)
    c.line_to(W, base + 0.5)
    c.stroke()
    img = over(img, FG, alpha_of(s) * 0.10)
    s, c = layer(W, H)
    for i in range(0, n, 16):
        x = x0 + i * step
        down = (i // 16) % 4 == 0
        c.set_line_width(DOWNBEAT if down else HAIR)
        c.move_to(x, base + 0.12 * H)
        c.line_to(x, base + 0.12 * H + (26 if down else 12) * k)
        c.stroke()
    img = over(img, FG, alpha_of(s) * 0.22 * fade_x)
    # the playhead: one vertical line, glow, the head at its top
    s, c = layer(W, H)
    c.set_line_width(ACTIVE)
    top = base - 0.30 * H
    c.move_to(play_x, top)
    c.line_to(play_x, base + 0.15 * H)
    c.stroke()
    ph = alpha_of(s) * smooth(top - 1, top + 0.10 * H, ys)
    img = over(img, CYAN_HI, blur(ph, 14 * k) * 0.35)
    img = over(img, CYAN_HI, ph)
    s, c = layer(W, H)
    c.arc(play_x, top, 5 * k, 0, 2 * math.pi)
    c.fill()
    img = over(img, CYAN_HI, alpha_of(s))
    return img


def handoff(W, H):
    """Two decks overlap; the head leaves one record and lands on the next."""
    k = H / 2160.0
    img, xs, ys = canvas(W, H)
    decks = [
        (W * 0.20, H * 1.30, (-10, 70), 0.42, 0.95),   # outgoing: left
        (W * 0.86, H * 1.18, (-75, 40), 0.40, 1.00),   # incoming: right, active
    ]
    tracks = [(0.00, 0.14), (0.18, 0.40), (0.44, 0.58), (0.62, 0.84), (0.88, 1.00)]
    out_pt = in_pt = None
    for i, (cx, cy, (ta, tb), rmin_f, gain) in enumerate(decks):
        theta = polar(xs, ys, cx, cy)
        r_max, r_min = cy - 0.24 * H, rmin_f * H
        sector = smooth(ta, ta + 24, theta) * (1 - smooth(tb - 20, tb, theta))
        grooves, edges = record(W, H, cx, cy, r_min, r_max, tracks, 14 * k)
        img = over(img, FG, grooves * 0.042 * gain * sector)
        img = over(img, FG, edges * 0.11 * gain * sector)
        r_play = r_min + (r_max - r_min) * tracks[3][0]
        if i == 0:
            # the outgoing head, in ink: still turning, no longer the active one
            s, c = layer(W, H)
            c.set_line_cap(cairo.LINE_CAP_ROUND)
            c.set_line_width(LINE)
            arc(c, cx, cy, r_play, 28, 40)
            c.stroke()
            trail = 0.15 + 0.85 * np.clip((theta - 28) / 12, 0, 1)
            img = over(img, FG, alpha_of(s) * 0.42 * trail)
            hx, hy = pt(cx, cy, r_play, 40)
            s, c = layer(W, H)
            c.arc(hx, hy, 3.6 * k, 0, 2 * math.pi)
            c.fill()
            img = over(img, FG, alpha_of(s) * 0.55)
            out_pt = (hx, hy)
        else:
            img = lift(img, xs, ys, *pt(cx, cy, r_play, -2), 0.6 * H, 0.055)
            ticks = beat_ticks(W, H, k, cx, cy, r_play - 12 * k, -48, 22, 1.6)
            img = over(img, FG, ticks * 0.24 * sector)
            img = playhead(img, W, H, k, cx, cy, r_play, -20, -2, theta, glow_strength=0.3)
            in_pt = pt(cx, cy, r_play, -20)
    # the handoff: a dotted path from the outgoing head to where the incoming one began
    s, c = layer(W, H)
    c.set_line_width(HAIR)
    c.set_dash([2 * DPR, 5 * DPR])
    (ax, ay), (bx, by) = out_pt, in_pt
    mx, my = (ax + bx) / 2, min(ay, by) - 0.10 * H
    c.move_to(ax, ay)
    c.curve_to(ax + (mx - ax) * 0.6, my, bx - (bx - mx) * 0.6, my, bx, by)
    c.stroke()
    img = over(img, FG, alpha_of(s) * 0.30)
    return img


def macro(W, H):
    """Grooves seen up close: the audio is in their wiggle; the stylus rides one of them."""
    k = H / 2160.0
    img, xs, ys = canvas(W, H)
    # a far centre (above-left) turns the grooves into a sweeping diagonal band
    cx, cy = -0.40 * W, -1.05 * H
    sx, sy = 0.72 * W, 0.64 * H                      # where the stylus sits
    r_mid = math.hypot(sx - cx, sy - cy)
    t_s = math.degrees(math.atan2(sx - cx, -(sy - cy)))
    pitch = 8.5 * k
    count = 190
    rng = np.random.default_rng(11)
    ts = np.linspace(t_s - 40, t_s + 40, 3000)
    rad = np.radians(ts - 90)
    sig_env = 0.35 + 0.65 * np.abs(np.sin(np.linspace(0, 7.0, ts.size))) ** 2
    s_off, c_off = layer(W, H)
    s_hot, c_hot = layer(W, H)
    hot = count // 2
    for g in range(count):
        r = r_mid + (g - hot) * pitch
        phase = rng.uniform(0, 2 * np.pi)
        wig = (np.sin(ts * 9.0 + phase) * 0.55 + np.sin(ts * 23.0 + phase * 1.7) * 0.30
               + np.sin(ts * 51.0 + phase * 0.6) * 0.15) * sig_env * 5.0 * k
        if g == hot:
            wig = wig * 0  # the groove under the stylus: drawn clean so the head reads
        x = cx + (r + wig) * np.cos(rad)
        y = cy + (r + wig) * np.sin(rad)
        c = c_hot if g == hot else c_off
        c.set_line_width(HAIR)
        c.move_to(x[0], y[0])
        for j in range(1, ts.size):
            c.line_to(x[j], y[j])
        c.stroke()
    rr = np.hypot(xs - cx, ys - cy)
    band = np.exp(-(((rr - r_mid) / (count * pitch * 0.34)) ** 2))  # depth of field
    rest = smooth(0.28 * W, 0.58 * W, xs + 0.60 * (ys - 0.30 * H))  # keep the top left empty
    top = smooth(0.10 * H, 0.22 * H, ys)                              # and the bar's band
    theta = polar(xs, ys, cx, cy)
    in_seg = (theta <= t_s) & (theta >= t_s - 3.0)
    img = over(img, FG, alpha_of(s_off) * (0.04 + 0.20 * band) * rest * top)
    hot_a = alpha_of(s_hot)
    img = over(img, FG, hot_a * 0.26 * rest * top * (~in_seg))
    trail = 0.15 + 0.85 * smooth(t_s - 3.0, t_s, theta)
    segment = hot_a * trail * in_seg
    img = lift(img, xs, ys, sx, sy, 0.55 * H, 0.06)
    img = over(img, CYAN_HI, blur(segment, 12 * k) * 0.5)
    img = over(img, CYAN_HI, np.clip(segment * 1.6, 0, 1))
    s, c = layer(W, H)
    c.arc(sx, sy, 5.2 * k, 0, 2 * math.pi)
    c.fill()
    head = alpha_of(s)
    img = over(img, CYAN_HI, blur(head, 18 * k) * 0.6)
    img = over(img, CYAN_HI, head)
    return img


FRAMES = {"sheen": (sheen, 21), "horizon": (horizon, 22), "handoff": (handoff, 23), "macro": (macro, 24)}

if __name__ == "__main__":
    name, w, h, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    fn, seed = FRAMES[name]
    finish(fn(w, h), out, seed)
    print(f"wrote {out} ({w}x{h})")
