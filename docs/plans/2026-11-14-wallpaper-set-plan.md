# Crate Wallpaper Set Implementation Plan

> **Shelved 2026-11-14.** The first two new wallpapers (Lead-in, Run-out) were rejected: the Groove
> motif was exhausted, they read as weaker copies of Groove, too empty and dark, and the parallax
> motion looked bad and seemed to deform the record. The set ships Groove alone, flat; depth and
> new motifs wait for a different approach. Not executed beyond Tasks 1 and 2, which were discarded.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Five Crate wallpapers (Groove, Lead-in, Run-out, Tonearm, Stack) rendered as Stage Parallax layers, laid down and registered by `crate-for-ryoku install`.

**Architecture:** One shared module (`wallpaper/crate_wall.py`) holds the tokens, the cairo/numpy helpers and a `Scene` that collects drawing into four ordered layers; one drawing function per wallpaper (`wallpaper/walls.py`). The renderer writes a flat lossless WebP plus a folder of layer PNGs and a `scene.json`. A separate installer script (`package/stage-scenes.sh`) copies the folders to `~/Pictures/Stage/` and registers each scene through `ryoku-shell stage` verbs.

**Tech Stack:** Python 3 with python-cairo, numpy and Pillow; bash; pytest.

**Spec:** `docs/plans/2026-11-14-wallpaper-set-design.md`

## Global Constraints

- Tokens: bg `#0a0a0f`, fg `#f1f5f9`, hairline fg at 10 %, cyan `#06b6d4`, cyan-hi `#67e8f9`.
- Stroke widths: 1 / 1.5 / 2.25 CSS px times 1.6667 (`HAIR`, `LINE`, `ACTIVE`), downbeat 1.75 CSS px.
- One size: 3840x2400. One cyan active element per wallpaper. No text, no logos.
- The top 20 % of every layer except `background` carries no structure (alpha 0).
- Layers and Stage index order: index 0 `subject.png` (depth 1.0), index 1 `layer-01.png` (far, 0.2), index 2 `layer-02.png` (near, 0.5); `background.png` is opaque and not an indexed layer. Every layer `front: false`.
- Each layer's content runs past the frame edges by at least 4 % of the width where the motif reaches an edge (no stroke ends at the frame).
- Grain (seed 132, 0.045 x 0.18 of 255, as in `groove.py`) lives in `background.png` only.
- Flats: `crate-<name>.webp`, lossless. Scene folders: `crate-<name>/`.
- The repo is public: no live-desktop captures or personal paths in it.
- Commits: `area: summary` (e.g. `wallpaper: ...`, `package: ...`), no AI attribution.
- Every new wallpaper passes the review gate (flat + parallax preview shown to the user, approved) before its commit.

## Review Focus

1. A 16:9 screen crops a 16:10 image (fill): the active element must not slide under the bar. Task 1 adds `test_active_element_clears_the_bar_on_16_9`: the subject layer's topmost opaque row is below `0.2 * H + 0.05 * H` (20 % plus the 16:9 crop).
2. The Stage daemon is not running when the installer runs (first install from a TTY): the installer warns and goes on. Task 7 adds `stub_fails` to the installer test.
3. A Pictures folder whose path has a space or an accent (localized `xdg-user-dir`): Task 7's test runs with `PICS="$tmp/Mis Imágenes"`.
4. The rice is re-applied after install and rewrites `crate.<ext>` with a new time: the scene goes stale. Task 7 adds `test_rerun_retouches_stale_layers`: an unchanged scene whose wallpaper became newer is touched again on rerun.
5. The user already has a Stage entry for `crate-groove` (an older model cut with front/depth flags): `set-layer` must override them. Task 8 checks it live.

---

### Task 1: Shared module, Groove in layers, generator tests

**Files:**
- Create: `wallpaper/crate_wall.py`, `wallpaper/walls.py`, `wallpaper/tests/test_walls.py`, `wallpaper/tests/fixtures/groove-960x600.png`
- Delete (end of task): `wallpaper/groove.py`

**Interfaces:**
- Produces in `crate_wall.py`: constants `BG, FG, CYAN, CYAN_HI, DPR, HAIR, LINE, ACTIVE, DOWNBEAT`; `layer(W, H) -> (cairo.ImageSurface, cairo.Context)`; `alpha_of(surface) -> np.ndarray[float32, HxW]`; `arc(ctx, cx, cy, r, t0, t1)`; `point(cx, cy, r, theta) -> (x, y)`; `LAYERS = ("background", "far", "near", "subject")`; class `Scene(W, H)` with `over(layer: str, color: tuple, alpha: np.ndarray) -> None`, `grain(seed: int = 132) -> None`, `flat() -> np.ndarray[uint8, HxWx3]`, `layer_rgba(name) -> np.ndarray[uint8, HxWx4]` (straight alpha), `write(flat_png: str, layer_dir: str) -> None`.
- Produces in `walls.py`: `WALLS: dict[str, Callable[[Scene], None]]` and CLI `python3 walls.py NAME W H FLAT.png LAYER_DIR` (and `--list`).
- `scene.json` shape: `{"name": "groove", "layers": [{"index": 0, "file": "subject.png", "label": "Subject", "depth": 1.0, "front": false}, {"index": 1, "file": "layer-01.png", "label": "Far", "depth": 0.2, "front": false}, {"index": 2, "file": "layer-02.png", "label": "Near", "depth": 0.5, "front": false}]}`.

- [ ] **Step 1: Pin today's Groove.** Before touching code: `python3 wallpaper/groove.py 960 600 wallpaper/tests/fixtures/groove-960x600.png`.
- [ ] **Step 2: Write the failing tests** in `wallpaper/tests/test_walls.py`, rendered at 960x600 into `tmp_path`; every test except the first is parametrised over the names in `WALLS`:
  - `test_groove_matches_the_reference`: new flat vs fixture, mean abs diff <= 0.5, max <= 8.
  - `test_layers_compose_to_the_flat`: background then layer-01, layer-02, subject composited (straight alpha, 8-bit) equals the flat with max abs diff <= 2.
  - `test_layers_share_the_size` and `test_scene_json_lists_three_indexed_layers` (values as in Interfaces).
  - `test_alpha_is_clean`: in each layer, pixels with alpha 0 have rgb 0.
  - `test_top_band_is_empty`: alpha 0 in rows `< 0.20 * H` of layer-01, layer-02 and subject.
  - `test_active_element_clears_the_bar_on_16_9` (Review Focus 1).
  - `test_one_cyan_element`: in the flat, pixels with b - r > 40 lie only where the subject layer's alpha > 0 or within the background's lift.
- [ ] **Step 3: Run** `cd wallpaper && python3 -m pytest tests -q`; expected: import error (no `walls`).
- [ ] **Step 4: Implement** `crate_wall.py` (helpers moved from `groove.py`; `Scene` keeps a float RGB background initialised to `BG` and three premultiplied RGBA float layers; `over` on background is today's `over`, on a layer it is premultiplied source-over; `flat()` composites in `LAYERS` order then adds the uniform dither and rounds, as `groove.py` does) and `groove(scene)` in `walls.py` with Groove's exact geometry: lift -> background; grooves -> far; track edges, ticks (both off and in-play) -> near; glow, trail, dot -> subject; then `scene.grain(132)`.
- [ ] **Step 5: Run** the tests; expected: all pass. Delete `groove.py`.
- [ ] **Step 6: Commit** `wallpaper: render Groove as Stage depth layers from a shared scene`.

### Task 2: Renderer, preview, packaging; retire the old series

**Files:**
- Modify: `wallpaper/render.sh`, `package/build.sh:34-35`
- Create: `wallpaper/preview.py`
- Delete: `wallpaper/series.py`, `wallpaper/review.html`

**Interfaces:**
- Consumes: `walls.py` CLI (Task 1).
- Produces: `render.sh OUT_DIR` writes `OUT_DIR/crate-<name>.webp` and `OUT_DIR/crate-<name>/{background,subject,layer-01,layer-02}.png,scene.json` for every name in `walls.py --list` at 3840x2400, skipping a name whose webp exists. `preview.py LAYER_DIR OUT.gif [--width 960]`: 24 frames, each layer shifted horizontally by `depth * 0.04 * width * sin(2*pi*t)`, background by `0.04 * 0.25 * width * sin(...)`, over 2.4 s.

- [ ] **Step 1:** Rewrite `render.sh`, then run `wallpaper/render.sh <scratch>/walls`; expected: `crate-groove.webp` and `crate-groove/` with five files.
- [ ] **Step 2:** `build.sh` copies `build/wallpapers/crate-*.webp` and the `crate-*/` folders into `$OUT/wallpapers/`. Run `package/build.sh`; expected: `dist/.../wallpapers/crate-groove/scene.json` exists.
- [ ] **Step 3:** Write `preview.py`; run it on `crate-groove/`; look at the GIF: the playhead drifts more than the grooves.
- [ ] **Step 4: Commit** `wallpaper: render flats and Stage scenes, add a parallax preview, retire the old series`.

### Tasks 3 to 6: the new wallpapers

One task each, same shape. Each adds a function to `walls.py`, registers it in `WALLS`, and is covered by Task 1's parametrised tests (which iterate `WALLS`).

| Task | Function | Spec row | Layer split |
|---|---|---|---|
| 3 | `lead_in` | Lead-in: Groove mirrored, record from the left, the start of the record, very short trail | as Groove |
| 4 | `run_out` | Run-out: centre low in frame, label edge in view, inner grooves, run-out spiral, long trail | label edge and spiral -> near |
| 5 | `tonearm` | Tonearm: close crop, arm in hairlines from the right edge below the bar band to the stylus; stylus dot cyan | record grooves -> far/near; arm and stylus -> subject |
| 6 | `stack` | Stack: three records overlapping in perspective; the front one plays | back record -> far; middle -> near; front record with its playhead -> subject |

- [ ] **Step 1:** Add the function; run `python3 -m pytest tests -q`; expected: the parametrised tests pass for the new name.
- [ ] **Step 2:** Render it at 3840x2400 with `render.sh` and a preview GIF with `preview.py`.
- [ ] **Step 3: Review gate.** Show the user the flat and the GIF. Stop until they approve; redraw on feedback.
- [ ] **Step 4: Commit** `wallpaper: add <Name>`.

### Task 7: Installer lays down and registers the scenes

**Files:**
- Create: `package/stage-scenes.sh`, `package/tests/stage-scenes-test.sh`
- Modify: `package/install.sh:120-139` (one size, copy `crate-*.webp` straight), `package/install.sh` (call `stage-scenes.sh install "$HERE"` after the apply block, unless `--no-wallpapers`), `package/uninstall.sh:91-97` (`--purge` also runs `stage-scenes.sh purge` and removes old and new flat names), `package/build.sh` (ship `stage-scenes.sh`)

**Interfaces:**
- `stage-scenes.sh install HERE` and `stage-scenes.sh purge`, reading `PICS` (xdg-user-dir PICTURES or `~/Pictures`) and `STATE` (`${XDG_STATE_HOME:-~/.local/state}/crate-for-ryoku`). Manifest: `$STATE/stage-scenes.sha256` (`sha256sum` lines, paths relative to `$PICS/Stage`).
- Per scene `crate-<name>`: wall `$PICS/Wallpapers/crate-<name>.webp`, folder `$PICS/Stage/crate-<name>/`. Groove also to `$PICS/Stage/crate/` against `$PICS/Wallpapers/crate.<ext>` when that file exists.

- [ ] **Step 1: Write the failing test** `package/tests/stage-scenes-test.sh` (bash, `set -euo pipefail`, temp HOME, `PICS="$tmp/Mis Imágenes"` through a stub `xdg-user-dir`, a stub `ryoku-shell` that appends its arguments to a log; fixture scenes built with tiny PNGs). Cases:
  - files land in `Stage/crate-<name>/` without `scene.json`;
  - `subject.png` is newer than its wallpaper and `background.png` newer than `subject.png`;
  - the log holds `stage set-effect parallax -- <wall>` and `stage set-layer 0 {"enabled":true,"front":false,"depth":1.0} -- <wall>` (and indexes 1, 2 with 0.2, 0.5);
  - an unrelated `Stage/other/` folder is untouched;
  - a user-changed scene (one byte changed in its `subject.png`) is neither overwritten on rerun nor deleted by `purge`;
  - `test_rerun_retouches_stale_layers` (Review Focus 4);
  - `stub_fails`: with `ryoku-shell` exiting 1 the script warns and exits 0 (Review Focus 2);
  - `purge` removes unchanged folders, sends `stage set-effect off -- <wall>`, and clears the manifest lines.
- [ ] **Step 2: Run** `bash package/tests/stage-scenes-test.sh`; expected: fails (no script).
- [ ] **Step 3: Implement** `stage-scenes.sh` (a scene is user-changed when any file in its folder is missing from, or differs from, the manifest; times set with `touch -d @$((wall_mtime + 1))` for `subject.png` and `+ 2` for the rest) and the `install.sh`/`uninstall.sh`/`build.sh` changes.
- [ ] **Step 4: Run** the test; expected: `stage-scenes-test: ok`. Run `bash -n` on the three scripts.
- [ ] **Step 5: Commit** `package: lay down and register the Stage scenes of the wallpaper set`.

### Task 8: Live install and check

- [ ] **Step 1:** `package/build.sh`, then from `dist/crate-for-ryoku-<version>/`: `./install.sh` (Crate is the active rice, so it is not re-applied). Expected output names the five scenes.
- [ ] **Step 2:** Check `~/.local/state/ryoku/stage-walls.json` for `crate-groove.webp`: effect `parallax`, subject depth 1.0 and `front: false` (Review Focus 5), layers 1 and 2 at 0.2 and 0.5.
- [ ] **Step 3:** Ask the user to switch through the five wallpapers and move the pointer; record their verdict. Update the design-system plan's Wave 6 with the set's status and commit `docs: record the wallpaper set in Wave 6`.
