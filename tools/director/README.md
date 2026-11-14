# director

Runs a screencast timeline on the live desktop so every take is the same and can be
re-recorded when something changes. Python 3 standard library only.

```sh
tools/director/director.py tools/director/timelines/example.json --dry-run
tools/director/director.py tools/director/timelines/hero.json \
  --record tools/cut/public/takes/hero.mp4 --output eDP-1
```

`--dry-run` prints each step's time and the exact commands. `--record` starts
`wf-recorder -r 60 [-o OUTPUT] -f OUT` first (creating the folder) and stops it with
SIGINT after the last step. `--output` records one monitor, so the terminal can sit
on another.

If a command fails, an app is missing, the recorder dies, or you press Ctrl+C, the
run stops, the recorder stops, and the take is renamed `NAME.failed.mkv`: a broken
take never keeps the real name. Takes go in `takes/`, which git ignores.

With `--output`, a good take also gets `NAME.marks.json` for the cut (tools/cut):
the output's geometry and, per step, the real time since the recorder started
(cues included), with the surface's `focus` (a 0..1 rectangle on the output,
declared per surface in the timeline) or the click point. A failed take gets none.

## Timeline

```json
{
  "name": "hero",
  "output": "hero.mkv",
  "surfaces": {
    "hub-widgets": {
      "open": ["ryoku-shell", "hub", "open", "widgets"],
      "close": ["hyprctl", "dispatch", "closewindow", "class:ryoku-hub"]
    }
  },
  "steps": [{ "at": 3, "do": "surface", "name": "hub-widgets", "action": "open" }]
}
```

Steps run in order at `at` seconds from the start; times never go backwards.

| `do` | Fields | Runs |
|---|---|---|
| `surface` | `name`, `action` | the `surfaces[name][action]` command |
| `window` | `run`, optional `dispatch` | `run` detached, then `hyprctl dispatch <each>` |
| `notify` | `title`, `body`, optional `app` (Crate) | `notify-send -a app title body` |
| `play` | `action` (play, pause, play-pause, next, previous, stop), optional `player` (crate) | `playerctl -p player action` |
| `pointer` | `to: [x, y]` (layout coordinates), optional `click` | `hyprctl dispatch movecursor x y`, `ydotool click 0xC0` |
| `wait` | | nothing; holds the timeline |
| `cue` | `message` | prints the message and waits for Enter |

A `cue` is for a surface that cannot be opened from a terminal: the run pauses, you
open it by its shortcut, and you resume, and the rest of the timeline moves back by
the time you took. Resume with Enter in the director's terminal, or, to keep the
terminal out of the take, with SIGUSR1 from a keybind that does not show on screen:

```
# ~/.config/hypr: resume the director's cue
bind = SUPER CTRL, F12, exec, pkill -USR1 -f tools/director/director.py
```

Surface commands live in each timeline, not in this script, because how each Ryoku
surface opens is probed on the desktop (below).

## Requirements

- `wf-recorder` (`sudo pacman -S wf-recorder`) for `--record`.
- `wtype` to close surfaces with Escape.
- `ydotool` with its daemon running, only for `pointer` steps that click.
- `playerctl`, `notify-send`, `hyprctl`, `ryoku-shell` (present on a Ryoku desktop).

## Surface probe

Probed live on 2026-11-14 (Hyprland, crate theme, three monitors). Shell surfaces
open on the monitor under the pointer, not the focused one: every timeline starts
with a `pointer` step that parks the cursor on the recorded output.

| Surface | Open | Close | From the director? |
|---|---|---|---|
| Launcher (Crate Palette) | `hyprctl dispatch 'hl.dsp.global("ryoku:launcher")'` | `wtype -k Escape` | yes |
| Controls | `hyprctl dispatch 'hl.dsp.global("ryoku:quicksettings")'` | `wtype -k Escape` | yes |
| Game Bar | `hyprctl dispatch 'hl.dsp.global("ryoku:gamebar")'` | same (toggle) | yes |
| Wallpaper picker | `qs -c shell ipc call picker wallpaper` | `wtype -k Escape` | yes |
| Kit | `ryoku-kit` | `wtype -k Escape` | yes (check close on the first take) |
| Notifications | `notify` step | timeout | yes |
| shima dock | always visible | | n/a |
| crate-mark panel | click the pill on the QS Bar | click again | no: a `cue`, or a `pointer` click with ydotool |

The QS Bar's IPC exposes only `layout` and `settings`, so the crate-mark popout has
no command. Pressing a shortcut works too: `wtype -M logo -k Escape -m logo` is
Super+Esc. QS Bar Settings is never opened from a terminal on this desktop.

## Tests

```sh
python3 -m pytest tools/director/tests -q
```
