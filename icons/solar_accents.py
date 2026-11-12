#!/usr/bin/env python3
"""Measure which duotone layer of each vendored extra glyph is the lighter one.

build_icons.py draws one layer of every glyph in cyan: the lighter of the two,
measured by rendering each layer alone (the rule the hand-drawn set follows, so
the accent is a small element, never the frame). This renders each layer of
solar-line-duotone-extra.json with rsvg-convert, counts its pixels and stores
the answer as the file's "accents" map. Run it after solar_export_perf.mjs.

usage: solar_accents.py [solar-line-duotone-extra.json]
"""
import io
import json
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image

EL = re.compile(r"<(path|circle|rect|ellipse|line|polyline|polygon)\b[^>]*>(?:</\1>)?")
FADE = 'style="opacity:var(--solar-secondary-opacity, 0.5)"'


def coverage(elements):
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24" '
           'fill="none" stroke-width="1.5">' + "".join(elements).replace("currentColor", "#ffffff") + "</svg>")
    png = subprocess.run(["rsvg-convert", "-w", "96", "-h", "96"], input=svg.encode(),
                         capture_output=True, check=True).stdout
    alpha = np.asarray(Image.open(io.BytesIO(png)).convert("RGBA"))[..., 3]
    return int((alpha > 64).sum())


def main(path):
    data = json.load(open(path))
    accents = {}
    for name, markup in data["icons"].items():
        els = [m.group(0) for m in EL.finditer(markup)]
        faded = [e.replace(FADE, "") for e in els if "solar-secondary" in e]
        solid = [e for e in els if "solar-secondary" not in e]
        if not faded or not solid:
            accents[name] = None  # one layer: all ink
            continue
        accents[name] = "secondary" if coverage(faded) <= coverage(solid) else "primary"
    data["accents"] = accents
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
    print(f"measured {len(accents)} glyphs in {path}")


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "solar-line-duotone-extra.json"))
