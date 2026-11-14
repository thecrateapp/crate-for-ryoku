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
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

KINDS = ("surface", "window", "notify", "play", "pointer", "type", "key", "wait", "cue")
PLAY_ACTIONS = ("play", "pause", "play-pause", "next", "previous", "stop")
RECORDER = ["wf-recorder", "-r", "60"]
COMMAND_TIMEOUT = 15
GLIDE_FPS = 60
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
        return Timeline(data["name"], data["output"], surfaces, steps)


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
    elif kind == "cue":
        need("message")


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
    if step.kind == "key":
        mods = d.get("mods", [])
        press = [a for m in mods for a in ("-M", m)]
        release = [a for m in mods for a in ("-m", m)]
        return [("run", ["wtype", *press, "-k", d["key"], *release])]
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


def run(timeline: Timeline, env: Env, record: str | None = None, output: str | None = None) -> None:
    take = Path(record) if record else None
    recorder = None
    if take is not None:
        take.parent.mkdir(parents=True, exist_ok=True)
        argv = [*RECORDER, *(["-o", output] if output else []), "-f", str(take)]
        try:
            recorder = env.spawn(argv)
        except OSError as error:
            raise DirectorError(f"cannot start the recorder: {error}") from error
    finished = False
    try:
        start = env.clock()
        shift = 0.0  # time spent waiting on cues pushes the rest of the timeline back
        for step in timeline.steps:
            env.sleep(start + shift + step.at - env.clock())
            if recorder is not None and not recorder.alive():
                raise DirectorError(f"the recorder stopped before step {step.index}")
            if step.kind == "cue":
                before = env.clock()
                env.prompt(step.data["message"])
                shift += env.clock() - before
                continue
            if step.kind == "pointer" and "duration" in step.data:
                base = start + shift + step.at
                for offset, argv in glide(step.data):
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
    finally:
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


def system_env() -> Env:
    return Env(run=_run, spawn=_Process, clock=time.monotonic, sleep=lambda s: time.sleep(max(0.0, s)), prompt=_prompt)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("timeline", help="timeline JSON file")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="print the resolved commands with their times")
    mode.add_argument("--record", metavar="OUT.mkv", help="record the screen with wf-recorder while running")
    parser.add_argument("--output", metavar="NAME", help="record only this output (wf-recorder -o), e.g. DP-1")
    args = parser.parse_args(argv)
    try:
        timeline = Timeline.load(args.timeline)
        if args.dry_run:
            print("\n".join(dry_run(timeline)))
            return 0
        run(timeline, system_env(), record=args.record, output=args.output)
    except DirectorError as error:
        print(f"director: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
