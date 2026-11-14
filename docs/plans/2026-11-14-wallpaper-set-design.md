# Crate Wallpaper Set: Design

> **Shelved 2026-11-14.** The first two new wallpapers (Lead-in, Run-out) were rejected: the Groove
> motif was exhausted, they read as weaker copies of Groove, too empty and dark, and the parallax
> motion looked bad and seemed to deform the record. The set ships Groove alone, flat; depth and
> new motifs wait for a different approach. Kept for the findings on Stage below.

Status: design, agreed with the user on 2026-11-14 (Wave 6 of the design-system plan). Implementation
plan to follow once this spec is approved.

## Goal

A short set of Crate wallpapers in the language of Crate Groove, the one wallpaper of the earlier
series the user kept, each one built in depth layers so Ryoku's Stage Parallax mode moves them
out of the box. `crate-for-ryoku install` lays them down ready to use.

The earlier series (Sheen, Horizon, Handoff, Macro in `wallpaper/series.py`) did not convince the
user and is retired.

## The set

Five wallpapers, one size: 3840x2400 (16:10). The compositions keep empty bands, so a 16:9 screen
crops only background; a second 3840x2160 render is not needed.

| # | Name | Composition | Moment of play |
|---|---|---|---|
| 1 | **Groove** | Today's `crate-groove`, unchanged to the eye: the groove centre below the bottom right corner, one sector of hairlines, the playhead on the upper track | Mid-record, a medium trail |
| 2 | **Lead-in** | Groove mirrored: the record enters from the left, the right side stays empty | The start: the outer edge and the lead-in groove, a very short trail |
| 3 | **Run-out** | Further back: the record's centre low in the frame, the edge of the label in view | The end: the inner grooves, the run-out spiral, a long trail |
| 4 | **Tonearm** | A close crop of the record with the tonearm drawn in hairlines entering from the right edge, below the bar band, to the stylus on the groove | Mid-record; the stylus dot is the cyan element |
| 5 | **Stack** | Three records overlapping in perspective, like the front of a record crate | The front record is playing: its playhead is the cyan element |

### Rules (all five)

- Crate v3 tokens, as `groove.py` states them: bg `#0a0a0f`, fg `#f1f5f9`, hairline fg at 10 %,
  cyan `#06b6d4`, cyan-hi `#67e8f9`.
- Stroke widths are the web figure widths (1 / 1.5 / 2.25 CSS px) times 1.6667.
- One active element in cyan per wallpaper; everything else is ink at low alpha.
- The top 20 % stays empty (the bar's rest band), and one side stays empty for windows.
- No text, no logos.
- The same grain and dither as Groove.

## Depth layers

Each wallpaper is rendered from one scene description into ordered layers of the same pixel size.
No cut-out model is involved: every layer is drawn with its own alpha, so edges are exact and leave
no halo when a layer moves.

| Layer file | Holds | Depth |
|---|---|---|
| `background.png` (opaque) | the field, the low cyan lift around the active element, grain | backdrop |
| `layer-01.png` | far structure: the faintest hairlines | 0.2 |
| `layer-02.png` | near structure: track edges, beat ticks, and for Stack the middle record | 0.5 |
| `subject.png` | the active element: playhead arc, glow, stylus dot; for Tonearm the arm; for Stack the front record | 1.0 |

Per wallpaper the split follows what is physically in front: Tonearm's arm floats over the record,
and Stack's three records sit at three depths. All layers sit behind desktop widgets (`front: false`).

**Flat equals the stack.** Compositing `background`, `layer-01`, `layer-02` and `subject` in that
order gives the flat wallpaper exactly (grain lives in the background only). The flat file is what
Plain mode, Ryogami's picker and the rice preview show.

**Motion.** Stage Parallax moves each layer with the pointer by up to 4 % of the screen width times
its depth; nothing is scaled to hide edges, so each layer carries a 4 % margin of its own content
(hairlines run past the frame edge, never stop at it). Defaults: pointer motion on at `normal`,
no idle motion, music reaction off (it suits Crate and stays one switch away in Stage). The Crate
rice carries these as its `stage.json` look (see the rice refresh task).

Out of scope: Spatial mode (a depth-map mesh), animated or video wallpapers (Stage skips them),
and the legacy per-workspace `parallax` block in rice.json, which no code reads.

## Generator

`wallpaper/` is rebuilt around one shared module:

- `crate_wall.py`: tokens, stroke widths, the cairo/numpy helpers now duplicated in `groove.py` and
  `series.py`, and a `Scene` that collects drawing into named layers and writes them.
- One function per wallpaper (`groove`, `lead_in`, `run_out`, `tonearm`, `stack`) that draws into
  a `Scene`.
- `render.sh OUT_DIR` writes, per wallpaper, `crate-<name>.webp` (the flat, lossless) and
  `crate-<name>/` with the four layer PNGs and a `scene.json` manifest (layer file, label, depth).
  Unchanged renders are kept, as today.

Groove keeps its exact geometry; its flat render must match today's `crate-groove` within dither
noise (a test pins this).

## Installation

`package/install.sh` (behind `crate-for-ryoku install`):

1. Copies each flat to `~/Pictures/Wallpapers/crate-<name>.webp` and each layer folder to
   `~/Pictures/Stage/crate-<name>/`. Groove's layers also go to `~/Pictures/Stage/crate/`, because
   applying the rice copies its wallpaper as `~/Pictures/Wallpapers/crate.png` and Stage keys a
   scene by the wallpaper's file stem.
2. Runs after the rice is applied, then touches every layer so it is newer than its wallpaper
   (Stage treats an older artifact as stale and does not draw it).
3. Registers each scene through Stage's own verbs, scoped to that wallpaper:
   `ryoku-shell stage set-effect parallax -- <wall>`, then `stage set-layer <index> <json> -- <wall>`
   for each layer with its depth and `front: false` from `scene.json`. Stage stores them in
   `~/.local/state/ryoku/stage-walls.json` and keeps them across refreshes (it carries each layer's
   flags forward by file path), and other wallpapers' entries are never touched.
4. A scene the user has changed since install (its folder or entry differs from what was laid
   down) is left alone on reinstall and on uninstall.

`uninstall` follows the installer's existing rule for wallpapers: they and their scenes stay
unless `--purge`, which removes the wallpapers, scene folders and Stage entries it laid down, under
the same user-changed rule.

The rice's own `wall.png` stays Groove's flat.

## Review gate

Each new wallpaper is shown to the user as a flat render and a short parallax preview before it
joins the set; a wallpaper the user does not like is redrawn or dropped, not shipped.

## Tests

- Generator (pytest): per wallpaper, the layers are the same size; compositing them equals the
  flat within one level of dither; layer alpha is premultiplied-clean (no coloured fringe where
  alpha is low); the top 20 % band carries no structure; Groove's flat matches the reference.
- Installer (a shell test with a temporary HOME and a stub `ryoku-shell`): files land where
  stated, layers are newer than their wallpaper, Stage receives the effect and each layer's depth
  for the five scenes, an unrelated Stage folder is untouched, a user-changed scene survives
  reinstall and `--purge`.
