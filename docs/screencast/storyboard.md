# Screencast storyboard

Status: DRAFT for Diego's review. Nothing is recorded until this storyboard and the
dry-runs of its timelines are approved (ryoku.cratemusic.app plan, Task 6).

Three deliverables come from three timelines in `tools/director/timelines/`:

| Deliverable | Timeline | Length | Use |
|---|---|---|---|
| Hero loop | `hero.json` | 36 s, seamless | the site's full-screen hero |
| Surface clips | `surfaces.json` | 8 shots of 6 s, cut apart | the Surfaces grid |
| Reddit cut | `reddit.json` | 75 s | r/unixporn post, 16:9 and 9:16 |

Every surface whose terminal command is not yet probed is a `cue` in the timelines:
the run pauses and you open it by its shortcut. After the probe (director README),
cues that turn out to paint from a command become `surface` steps.

## Open question: Crate Decks

The plan asks whether Crate Decks (the DJ app) is Crate-styled enough to appear. If
yes, it gets one shot in the hero (between shots 4 and 5, 4 s, decks loaded) and one
in the Reddit cut (after shot R6, 6 s). Diego decides at the review.

## Pre-session checklist

- [ ] Do not disturb on; only the director's notifications show.
- [ ] Work windows closed; no mail, chats, terminals with paths, or other people's names.
- [ ] Groove wallpaper; Crate for Ryoku installed and `crate-for-ryoku status` all green.
- [ ] Crate desktop app signed in; a queue of tracks whose licence allows publishing
      (Reddit cut audio). Album covers on screen are fine; no private playlists.
- [ ] One 4K output active; the recorder targets it.
- [ ] `wf-recorder` installed; `ydotool` daemon running if a timeline uses `pointer`.
- [ ] Dry-run the timeline once; then record.

## Hero loop (36 s, seamless)

Starts and ends on the same frame: the bare desktop, Groove wallpaper, bar and dock,
Crate playing.

| # | At | Shot |
|---|---|---|
| H1 | 0-4 s | Bare desktop. Crate playing; the crate-mark on the QS Bar breathes. |
| H2 | 4-10 s | The crate-mark panel opens: now playing, transport, the equalizer curve. |
| H3 | 10-12 s | Panel closes. |
| H4 | 12-17 s | A notification slides in ("Crate: Now playing ..."), then leaves. |
| H5 | 17-24 s | The launcher opens; `cr ` is typed and Crate results appear; it closes. |
| H6 | 24-30 s | Controls (Super+Esc) opens and closes. |
| H7 | 30-36 s | The dock: the pointer drifts over two icons (hover lift), back to rest. |

## Surface clips (6 s each)

Each starts and ends on the bare desktop so it loops.

| # | Clip id | Shot |
|---|---|---|
| S1 | `qsbar` | crate-mark panel opens, the equalizer preset changes, it closes. |
| S2 | `controls` | Controls opens, a toggle flips, it closes. |
| S3 | `launcher` | Launcher opens, `cr` search shows Crate results, it closes. |
| S4 | `gamebar` | Game Bar opens over the desktop and closes. |
| S5 | `kit` | Kit: the Beam scans, a chip is picked, a slider moves. |
| S6 | `pickers` | Wallpaper picker opens on Groove and Sheen and closes. |
| S7 | `dock` | Pointer moves along the dock; lift and open-window dots. |
| S8 | `notifications` | Two notifications stack and dismiss. |

## Reddit cut (75 s)

| # | At | Shot |
|---|---|---|
| R1 | 0-6 s | Bare desktop, Crate playing; title card added in the edit. |
| R2 | 6-16 s | crate-mark panel: equalizer, presets. |
| R3 | 16-26 s | Launcher with `cr` search, play a result. |
| R4 | 26-36 s | Controls, then the Game Bar. |
| R5 | 36-46 s | Kit and the pickers. |
| R6 | 46-56 s | Terminal: fastfetch with the Crate emblem, eza in the Crate theme. |
| R7 | 56-66 s | The Crate desktop app full screen, then back. |
| R8 | 66-75 s | Bare desktop; end card with ryoku.cratemusic.app added in the edit. |

Audio: only in the Reddit cut, and only a track whose licence allows it.
