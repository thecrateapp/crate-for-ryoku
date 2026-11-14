# director

Runs a screencast timeline on the live desktop so every take is the same and can be
re-recorded when something changes. Python 3 standard library only.

```sh
tools/director/director.py tools/director/timelines/example.json --dry-run
tools/director/director.py tools/director/timelines/hero.json \
  --record tools/director/takes/hero.mkv --output DP-1
```

`--dry-run` prints each step's time and the exact commands. `--record` starts
`wf-recorder -r 60 [-o OUTPUT] -f OUT` first (creating the folder) and stops it with
SIGINT after the last step. `--output` records one monitor, so the terminal can sit
on another.

If a command fails, an app is missing, the recorder dies, or you press Ctrl+C, the
run stops, the recorder stops, and the take is renamed `NAME.failed.mkv`: a broken
take never keeps the real name. Takes go in `takes/`, which git ignores.

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
| `pointer` | `to: [x, y]`, optional `click` | `ydotool mousemove --absolute`, `ydotool click 0xC0` |
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
- `ydotool` with its daemon running, only for `pointer` steps.
- `playerctl`, `notify-send`, `hyprctl`, `ryoku-shell` (present on a Ryoku desktop).

## Surface probe

Each surface the storyboard needs, checked with a one-step timeline on the live
desktop: does it open and paint from the director, or does it need a `cue`?

| Surface | Open command | Paints from the director? |
|---|---|---|
| QS Bar crate-mark panel | to probe | to probe |
| Controls (Super+Esc) | to probe | to probe |
| Launcher (Super+Space) | to probe | to probe |
| Game Bar | to probe | to probe |
| Kit | to probe | to probe |
| Pickers | to probe | to probe |
| shima dock | always visible | n/a |
| Notifications | `notify` step | to probe |

QS Bar Settings is never opened from a terminal on this desktop: use a `cue`.

## Tests

```sh
python3 -m pytest tools/director/tests -q
```
