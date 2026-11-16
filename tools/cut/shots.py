"""Compose the ryoku.cratemusic.app showcase screenshots from director takes.

    python3 tools/cut/shots.py OUT_DIR            # takes from tools/cut/public/takes
    python3 tools/cut/shots.py OUT_DIR STILLS     # grim stills: STILLS/<id>.png
    make -C <crate repo> ryoku-media-sync SRC=<dir holding OUT_DIR as shots/>

Each shot is one 3840x2400 frame of eDP-1: a grim still (`grim -o eDP-1
STILLS/<id>.png`, sharper than a video frame) or, without STILLS, a frame of a
take read at the moment its surface is fully open (the take's marks give the
times). A slide crops the
region around the surface (wide 16:10 and portrait 4:5) and insets it on the
site background, so the showcase's edge feather (10% x, 12% y) only touches
background, like the Crate site's gallery shots. Needs ffmpeg and Pillow.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

TAKES = Path(__file__).resolve().parent / "public" / "takes"
OUT = Path(sys.argv[1])
STILLS = Path(sys.argv[2]) if len(sys.argv) > 2 else None
ONLY = set(sys.argv[3:])
OUT.mkdir(parents=True, exist_ok=True)

# id: (take, seconds into it)
FRAMES = {
    "desktop": ("showcase", 35.0),
    "qsbar": ("showcase", 38.6),
    "controls": ("showcase", 26.0),
    "launcher": ("showcase", 60.2),
    "gamebar": ("showcase", 71.6),
    "kit": ("showcase", 77.2),
    "pickers": ("showcase", 6.4),
    "notifications": ("showcase", 95.8),
    "dock": ("dock", 2.4),
}

BG = (10, 10, 15)  # --bg in app/web/src/styles/tokens.css
LINE = (255, 255, 255, 26)  # --line, roughly

# id: (wide crop x, y, width; height follows 16:10), (portrait centre x, y, height; width = 0.8 h)
SHOTS = {
    "desktop": ((0, 0, 3840), (2870, 1200, 2400)),
    "qsbar": ((1280, 0, 2560), (3014, 760, 1700)),
    "controls": ((640, 0, 2560), (1920, 700, 1600)),
    "launcher": ((640, 112, 2560), (1920, 912, 1500)),
    "gamebar": ((960, 0, 1920), (1920, 560, 1200)),
    "kit": ((320, 224, 3200), (1600, 1240, 2000)),
    "pickers": ((0, 0, 3840), (1920, 1150, 2300)),
    "notifications": ((2560, 0, 1280), (3480, 420, 900)),
    "dock": ((0, 600, 1920), (420, 1200, 1100)),
    # stills only (no take frame): pass STILLS
    "settings": ((0, 0, 3840), (960, 1200, 2400)),
    "ask": ((960, 80, 1920), (1920, 700, 1700)),
    "qsbar-settings": ((0, 40, 2240), (790, 760, 1900)),
    "audio": ((1280, 0, 2560), (3410, 700, 1500)),
    "network": ((1280, 0, 2560), (3250, 640, 1400)),
    "temperature": ((0, 0, 1920), (650, 520, 1150)),
    "rashin": ((640, 440, 2560), (1655, 1233, 2000)),
}

WIDE = (2560, 1440)
PORTRAIT = (1620, 2025)


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle(
        (0, 0, img.width - 1, img.height - 1), radius, outline=LINE, width=2
    )
    return out


def inset(crop: Image.Image, canvas_size: tuple[int, int], keep_x: float, keep_y: float) -> Image.Image:
    cw, ch = canvas_size
    box_w, box_h = cw * (1 - 2 * keep_x), ch * (1 - 2 * keep_y)
    scale = min(box_w / crop.width, box_h / crop.height)
    size = (round(crop.width * scale), round(crop.height * scale))
    shot = rounded(crop.resize(size, Image.LANCZOS), radius=max(8, round(size[0] / 110)))
    canvas = Image.new("RGBA", canvas_size, BG + (255,))
    canvas.alpha_composite(shot, ((cw - size[0]) // 2, (ch - size[1]) // 2))
    return canvas.convert("RGB")


def clamp(v: int, lo: int, hi: int) -> int:
    return max(lo, min(v, hi))


def frame_of(shot_id: str) -> Image.Image:
    if STILLS:
        return Image.open(STILLS / f"{shot_id}.png").convert("RGB")
    take, at = FRAMES[shot_id]
    with tempfile.TemporaryDirectory() as tmp:
        frame = Path(tmp) / "frame.png"
        subprocess.run(
            ["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-ss", str(at),
             "-i", str(TAKES / f"{take}.mp4"), "-frames:v", "1", str(frame)],
            check=True,
        )
        return Image.open(frame).convert("RGB")


for shot_id, ((x, y, w), (px, py, ph)) in SHOTS.items():
    if ONLY and shot_id not in ONLY:
        continue
    still = frame_of(shot_id)
    h = round(w * 10 / 16)
    wide = still.crop((x, y, x + w, y + h))
    pw = round(ph * 0.8)
    left = clamp(px - pw // 2, 0, still.width - pw)
    top = clamp(py - ph // 2, 0, still.height - ph)
    tall = still.crop((left, top, left + pw, top + ph))

    big = inset(wide, WIDE, 0.09, 0.11)
    big.save(OUT / f"{shot_id}.webp", quality=86, method=6)
    big.resize((1280, 720), Image.LANCZOS).save(OUT / f"{shot_id}-1280.webp", quality=86, method=6)
    portrait = inset(tall, PORTRAIT, 0.08, 0.1)
    portrait.save(OUT / f"{shot_id}-portrait.webp", quality=86, method=6)
    portrait.resize((1080, 1350), Image.LANCZOS).save(
        OUT / f"{shot_id}-portrait-1080.webp", quality=86, method=6
    )
    print(shot_id, "ok")
