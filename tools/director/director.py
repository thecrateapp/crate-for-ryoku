#!/usr/bin/env python3
"""Timeline-driven screencast director for Crate for Ryoku.

A timeline (JSON) lists steps at fixed times: open and close shell surfaces, launch
and place windows, send notifications, drive Crate's player, move the pointer, wait,
or pause with a cue for the person at the keyboard. `--dry-run` prints what would
run; `--record OUT.mkv` records the screen with wf-recorder while the steps run.
A failing step stops the run and the recorder, so a broken take is never kept.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import shlex
import signal
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

KINDS = ("surface", "window", "notify", "play", "pointer", "nudge", "type", "key", "wait", "cue")
PLAY_ACTIONS = ("play", "pause", "play-pause", "next", "previous", "stop")
RECORDER = ["wf-recorder", "-r", "60"]
COMMAND_TIMEOUT = 15
GLIDE_FPS = 60

# Linux evdev key codes (input-event-codes.h) for `key` steps. Ryoku binds shortcuts
# by keycode, so they are sent through ydotool's uinput keyboard, not wtype.
KEYCODES = {
    "super": 125, "shift": 42, "ctrl": 29, "alt": 56,
    "Escape": 1, "Return": 28, "Tab": 15, "space": 57, "BackSpace": 14,
    "Left": 105, "Right": 106, "Up": 103, "Down": 108,
    **{c: code for c, code in zip("1234567890", range(2, 12))},
    **{c: code for c, code in zip("qwertyuiop", range(16, 26))},
    **{c: code for c, code in zip("asdfghjkl", range(30, 39))},
    **{c: code for c, code in zip("zxcvbnm", range(44, 51))},
}
TYPE_DELAY_MS = 60


class DirectorError(RuntimeError):
    pass


@dataclass(frozen=True)
class Step:
    index: int
    at: float
    kind: str
    data: dict[str, Any]


@dataclass(frozen=True)
class Timeline:
    name: str
    output: str
    surfaces: dict[str, dict[str, list[str]]]
    steps: list[Step]
    # run when the take ends, however it ends: put back what the steps changed
    teardown: list[Step] = field(default_factory=list)

    @staticmethod
    def load(path: str | Path) -> "Timeline":
        try:
            data = json.loads(Path(path).read_text())
        except (OSError, json.JSONDecodeError) as error:
            raise DirectorError(f"cannot read {path}: {error}") from error
        return Timeline.from_dict(data)

    @staticmethod
    def from_dict(data: dict[str, Any]) -> "Timeline":
        for key in ("name", "output", "steps"):
            if key not in data:
                raise DirectorError(f"timeline is missing '{key}'")
        surfaces = data.get("surfaces", {})
        steps: list[Step] = []
        previous = 0.0
        for index, raw in enumerate(data["steps"], start=1):
            kind = raw.get("do")
            if kind not in KINDS:
                raise DirectorError(f"step {index}: unknown do {kind!r}")
            try:
                at = float(raw.get("at", -1))
            except (TypeError, ValueError):
                at = -1.0
            if at < 0:
                raise DirectorError(f"step {index}: 'at' must be a time in seconds")
            if steps and at < previous:
                raise DirectorError(f"step {index} starts before step {index - 1}")
            previous = at
            _validate(index, kind, raw, surfaces)
            steps.append(Step(index, at, kind, raw))
        teardown: list[Step] = []
        for index, raw in enumerate(data.get("teardown", []), start=1):
            kind = raw.get("do")
            if kind not in KINDS or kind in ("cue", "wait"):
                raise DirectorError(f"teardown {index}: unknown do {kind!r}")
            _validate(index, kind, raw, surfaces)
            teardown.append(Step(index, 0.0, kind, raw))
        return Timeline(data["name"], data["output"], surfaces, steps, teardown)


def _validate(index: int, kind: str, raw: dict[str, Any], surfaces: dict) -> None:
    def need(*keys: str) -> None:
        for key in keys:
            if key not in raw:
                raise DirectorError(f"step {index}: {kind} needs '{key}'")

    if kind == "surface":
        need("name", "action")
        surface = surfaces.get(raw["name"])
        if surface is None:
            raise DirectorError(f"step {index}: unknown surface {raw['name']!r}")
        if raw["action"] not in surface:
            raise DirectorError(f"step {index}: surface {raw['name']!r} has no {raw['action']!r} command")
    elif kind == "window":
        need("run")
    elif kind == "notify":
        need("title", "body")
    elif kind == "play":
        need("action")
        if raw["action"] not in PLAY_ACTIONS:
            raise DirectorError(f"step {index}: unknown play action {raw['action']!r}")
    elif kind == "pointer":
        need("to")
        if "duration" in raw and "from" not in raw:
            raise DirectorError(f"step {index}: a pointer glide needs 'from'")
    elif kind == "type":
        need("text")
    elif kind == "key":
        need("key")
        for name in [raw["key"], *raw.get("mods", [])]:
            if name not in KEYCODES:
                raise DirectorError(f"step {index}: unknown key {name!r}")
    elif kind == "cue":
        need("message")
    if kind in ("pointer", "key"):
        for key in ("opens", "closes"):
            if key in raw and raw[key] not in surfaces:
                raise DirectorError(f"step {index}: unknown surface {raw[key]!r}")


def commands(step: Step, timeline: Timeline) -> list[tuple[str, list[str]]]:
    """The commands a step runs, as (mode, argv); mode is 'run' or 'spawn'."""
    d = step.data
    if step.kind == "surface":
        return [("run", list(timeline.surfaces[d["name"]][d["action"]]))]
    if step.kind == "window":
        out = [("spawn", list(d["run"]))]
        # Hyprland 0.57+ dispatches Lua: each entry is passed as written,
        # e.g. 'hl.dsp.window.fullscreen()'.
        for dispatch in d.get("dispatch", []):
            out.append(("run", ["hyprctl", "dispatch", dispatch]))
        return out
    if step.kind == "notify":
        return [("run", ["notify-send", "-a", d.get("app", "Crate"), d["title"], d["body"]])]
    if step.kind == "play":
        return [("run", ["playerctl", "-p", d.get("player", "crate"), d["action"]])]
    if step.kind == "type":
        return [("run", ["wtype", "-d", str(TYPE_DELAY_MS), d["text"]])]
    if step.kind == "nudge":
        # a real device motion (hyprctl only warps): hover follows what moved under it
        return [("run", ["ydotool", "mousemove", "-x", "4", "-y", "0"]),
                ("run", ["ydotool", "mousemove", "-x", "-4", "-y", "0"])]
    if step.kind == "key":
        codes = [KEYCODES[m] for m in d.get("mods", [])] + [KEYCODES[d["key"]]]
        press = [f"{c}:1" for c in codes]
        release = [f"{c}:0" for c in reversed(codes)]
        return [("run", ["ydotool", "key", *press, *release])]
    if step.kind == "pointer" and "duration" in d:
        return [("run", argv) for _, argv in glide(d)] + (
            [("run", ["ydotool", "click", "0xC0"])] if d.get("click") else []
        )
    if step.kind == "pointer":
        x, y = d["to"]
        out = [("run", move_cursor(x, y))]
        if d.get("click"):
            out.append(("run", ["ydotool", "click", "0xC0"]))
        return out
    return []


def move_cursor(x: int, y: int) -> list[str]:
    """Moves the pointer to layout coordinates (Hyprland 0.57+ Lua dispatch)."""
    return ["hyprctl", "dispatch", f"hl.dsp.cursor.move({{x={x},y={y}}})"]


def glide(d: dict[str, Any]) -> list[tuple[float, list[str]]]:
    """A pointer glide: (seconds into the step, movecursor argv) per frame, eased
    in and out like the Beam, from `from` to `to` over `duration` seconds."""
    (x0, y0), (x1, y1) = d["from"], d["to"]
    duration = float(d["duration"])
    frames = max(2, round(duration * GLIDE_FPS))
    out = []
    for i in range(frames):
        t = i / (frames - 1)
        e = (1 - math.cos(math.pi * t)) / 2
        x, y = round(x0 + (x1 - x0) * e), round(y0 + (y1 - y0) * e)
        out.append((duration * t, move_cursor(x, y)))
    return out


def _label(step: Step) -> str:
    d = step.data
    if step.kind == "surface":
        return f"surface {d['name']} {d['action']}"
    if step.kind == "play":
        return f"play {d['action']}"
    return step.kind


def dry_run(timeline: Timeline) -> list[str]:
    lines = []
    for step in timeline.steps:
        head = f"{step.at:7.2f}  {_label(step)}"
        if step.kind == "cue":
            lines.append(f"{head}: {step.data['message']}")
            continue
        if step.kind == "pointer" and "duration" in step.data:
            d = step.data
            moves = glide(d)
            click = "; ydotool click 0xC0" if d.get("click") else ""
            lines.append(
                f"{head} glide {d['from']} -> {d['to']} over {d['duration']} s: "
                f"{len(moves)} x hl.dsp.cursor.move{click}"
            )
            continue
        cmds = commands(step, timeline)
        lines.append(f"{head}: {'; '.join(shlex.join(argv) for _, argv in cmds)}" if cmds else head)
    return lines


@dataclass(frozen=True)
class Env:
    run: Callable[[list[str]], int]
    spawn: Callable[[list[str]], Any]
    clock: Callable[[], float]
    sleep: Callable[[float], None]
    prompt: Callable[[str], None]


def failed_path(take: Path) -> Path:
    """Where a take that did not finish is moved: `hero.mkv` becomes `hero.failed.mkv`."""
    return take.with_name(f"{take.stem}.failed{take.suffix}")


def marks_path(take: Path) -> Path:
    """The cut's sidecar for a take: `hero.mkv` gets `hero.marks.json`."""
    return take.with_name(f"{take.stem}.marks.json")


def _fraction(point: list[float], geometry: dict[str, Any]) -> list[float]:
    """Layout coordinates to a 0..1 position on the recorded output."""
    width = geometry["width"] / geometry["scale"]
    height = geometry["height"] / geometry["scale"]
    return [round((point[0] - geometry["x"]) / width, 4), round((point[1] - geometry["y"]) / height, 4)]


def _with_surface_details(event: dict[str, Any], surface: dict[str, Any]) -> dict[str, Any]:
    """An opening carries the surface's `focus` (what the camera frames) and its `redact`
    boxes (private data the cut blurs while it is open)."""
    for key in ("focus", "redact"):
        if surface.get(key):
            event[key] = surface[key]
    return event


def _mark(step: Step, timeline: Timeline, t: float, geometry: dict[str, Any]) -> dict[str, Any] | None:
    d = step.data
    if step.kind == "pointer" and "duration" in d:
        t += float(d["duration"])  # a glide clicks when it lands
    base = {"t": round(t, 3), "step": step.index}
    if step.kind == "surface":
        event = {**base, "kind": d["action"], "surface": d["name"]}
        return _with_surface_details(event, timeline.surfaces[d["name"]]) if d["action"] == "open" else event
    if (step.kind == "pointer" and d.get("click")) or step.kind == "key":
        # A click or shortcut that opens or closes a surface (the crate-mark pill, Super+W)
        # marks it like a surface step, so the cut frames the panel.
        if "opens" in d:
            event = {**base, "kind": "open", "surface": d["opens"]}
            return _with_surface_details(event, timeline.surfaces[d["opens"]])
        if "closes" in d:
            return {**base, "kind": "close", "surface": d["closes"]}
        if step.kind == "key":
            return None
        return {**base, "kind": "click", "point": _fraction(d["to"], geometry)}
    if step.kind == "notify":
        return {**base, "kind": "notify"}
    if step.kind == "window":
        return {**base, "kind": "window"}
    return None


def run(
    timeline: Timeline,
    env: Env,
    record: str | None = None,
    output: str | None = None,
    geometry: dict[str, Any] | None = None,
    audio: str | None = None,
) -> None:
    take = Path(record) if record else None
    recorder = None
    if take is not None:
        take.parent.mkdir(parents=True, exist_ok=True)
        argv = [*RECORDER, *(["-o", output] if output else []), *([f"--audio={audio}"] if audio else []), "-f", str(take)]
        try:
            recorder = env.spawn(argv)
        except OSError as error:
            raise DirectorError(f"cannot start the recorder: {error}") from error
    finished = False
    events: list[dict[str, Any]] = []
    try:
        start = env.clock()
        shift = 0.0  # time spent waiting on cues pushes the rest of the timeline back
        for step in timeline.steps:
            env.sleep(start + shift + step.at - env.clock())
            if recorder is not None and not recorder.alive():
                raise DirectorError(f"the recorder stopped before step {step.index}")
            if geometry is not None:
                event = _mark(step, timeline, env.clock() - start, geometry)
                if event is not None:
                    events.append(event)
            if step.kind == "cue":
                before = env.clock()
                env.prompt(step.data["message"])
                shift += env.clock() - before
                continue
            if step.kind == "pointer" and "duration" in step.data:
                base = start + shift + step.at
                frames = glide(step.data)
                for i, (offset, argv) in enumerate(frames):
                    last = i == len(frames) - 1
                    # Running late (each move is a hyprctl call): skip this frame if the
                    # next one is already due, so the glide lands on time. Never skip the last.
                    if not last and env.clock() > base + frames[i + 1][0]:
                        continue
                    env.sleep(base + offset - env.clock())
                    if env.run(argv) != 0:
                        raise DirectorError(f"step {step.index} failed (pointer glide): {shlex.join(argv)}")
                if step.data.get("click") and env.run(["ydotool", "click", "0xC0"]) != 0:
                    raise DirectorError(f"step {step.index} failed (pointer click): ydotool click 0xC0")
                continue
            for mode, argv in commands(step, timeline):
                failure = f"step {step.index} failed ({_label(step)}): {shlex.join(argv)}"
                if mode == "spawn":
                    try:
                        env.spawn(argv)
                    except OSError as error:
                        raise DirectorError(f"{failure}: {error.strerror or error}") from error
                elif env.run(argv) != 0:
                    raise DirectorError(failure)
        finished = True
        if take is not None and geometry is not None:
            duration = round(env.clock() - start, 3)
            marks = {"take": take.name, "output": geometry, "duration": duration, "events": events}
            marks_path(take).write_text(json.dumps(marks, indent=2) + "\n")
    finally:
        # never let a teardown failure hide why the take stopped
        for step in timeline.teardown:
            for mode, argv in commands(step, timeline):
                try:
                    env.spawn(argv) if mode == "spawn" else env.run(argv)
                except OSError:
                    pass
        if recorder is not None:
            recorder.stop()
        # A take that did not reach the end is never left under its real name.
        if take is not None and not finished and take.exists():
            take.replace(failed_path(take))


class _Process:
    def __init__(self, argv: list[str]):
        # stdin is not shared: cues read the terminal, and wf-recorder would prompt on it.
        self.proc = subprocess.Popen(
            argv,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

    def alive(self) -> bool:
        return self.proc.poll() is None

    def stop(self) -> None:
        if self.proc.poll() is None:
            self.proc.send_signal(signal.SIGINT)  # wf-recorder finalises the file on SIGINT
            try:
                self.proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.proc.kill()


def _run(argv: list[str]) -> int:
    try:
        return subprocess.run(argv, timeout=COMMAND_TIMEOUT, stdout=subprocess.DEVNULL).returncode
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"director: {shlex.join(argv)}: {error}", file=sys.stderr)
        return 1


class _Resume(Exception):
    pass


def _resume(signum, frame):  # noqa: ARG001
    raise _Resume


def _prompt(message: str) -> None:
    """Waits for Enter in this terminal, or SIGUSR1 from a compositor keybind, so the
    terminal never has to come into frame during a take."""
    previous = signal.signal(signal.SIGUSR1, _resume)
    try:
        input(f"\n  CUE  {message}\n  Press Enter, or send SIGUSR1 (pid {os.getpid()}), to continue... ")
    except _Resume:
        print()
    finally:
        signal.signal(signal.SIGUSR1, previous)


def default_sink_monitor() -> str:
    """The PipeWire/Pulse monitor source of the default output: everything that plays."""
    try:
        sink = subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.TimeoutExpired) as error:
        raise DirectorError(f"cannot read the default output: {error}") from error
    if not sink:
        raise DirectorError("no default audio output")
    return f"{sink}.monitor"


def monitor_geometry(name: str) -> dict[str, Any]:
    """The recorded output's layout position, pixel size and scale, from Hyprland."""
    try:
        monitors = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=5).stdout)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as error:
        raise DirectorError(f"cannot read the monitors: {error}") from error
    for m in monitors:
        if m.get("name") == name:
            return {k: m[k] for k in ("name", "x", "y", "width", "height", "scale")}
    raise DirectorError(f"no monitor named {name!r}")


def system_env() -> Env:
    return Env(run=_run, spawn=_Process, clock=time.monotonic, sleep=lambda s: time.sleep(max(0.0, s)), prompt=_prompt)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("timeline", help="timeline JSON file")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="print the resolved commands with their times")
    mode.add_argument("--record", metavar="OUT.mkv", help="record the screen with wf-recorder while running")
    parser.add_argument("--output", metavar="NAME", help="record only this output (wf-recorder -o), e.g. DP-1")
    parser.add_argument("--audio", action="store_true", help="also record what plays on the default output (its monitor)")
    args = parser.parse_args(argv)
    try:
        timeline = Timeline.load(args.timeline)
        if args.dry_run:
            print("\n".join(dry_run(timeline)))
            return 0
        geometry = monitor_geometry(args.output) if args.record and args.output else None
        audio = default_sink_monitor() if args.record and args.audio else None
        run(timeline, system_env(), record=args.record, output=args.output, geometry=geometry, audio=audio)
    except DirectorError as error:
        print(f"director: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
