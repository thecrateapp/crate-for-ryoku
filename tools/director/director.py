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
import shlex
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

KINDS = ("surface", "window", "notify", "play", "pointer", "wait", "cue")
PLAY_ACTIONS = ("play", "pause", "play-pause", "next", "previous", "stop")
RECORDER = ["wf-recorder", "-r", "60"]
COMMAND_TIMEOUT = 15


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
            at = float(raw.get("at", -1))
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
    elif kind == "cue":
        need("message")


def commands(step: Step, timeline: Timeline) -> list[tuple[str, list[str]]]:
    """The commands a step runs, as (mode, argv); mode is 'run' or 'spawn'."""
    d = step.data
    if step.kind == "surface":
        return [("run", list(timeline.surfaces[d["name"]][d["action"]]))]
    if step.kind == "window":
        out = [("spawn", list(d["run"]))]
        for dispatch in d.get("dispatch", []):
            name, _, args = dispatch.partition(" ")
            out.append(("run", ["hyprctl", "dispatch", name, *([args] if args else [])]))
        return out
    if step.kind == "notify":
        return [("run", ["notify-send", "-a", d.get("app", "Crate"), d["title"], d["body"]])]
    if step.kind == "play":
        return [("run", ["playerctl", "-p", d.get("player", "crate"), d["action"]])]
    if step.kind == "pointer":
        x, y = d["to"]
        out = [("run", ["ydotool", "mousemove", "--absolute", "-x", str(x), "-y", str(y)])]
        if d.get("click"):
            out.append(("run", ["ydotool", "click", "0xC0"]))
        return out
    return []


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


def run(timeline: Timeline, env: Env, record: str | None = None) -> None:
    recorder = env.spawn([*RECORDER, "-f", record]) if record else None
    try:
        start = env.clock()
        shift = 0.0  # time spent waiting on cues pushes the rest of the timeline back
        for step in timeline.steps:
            env.sleep(start + shift + step.at - env.clock())
            if step.kind == "cue":
                before = env.clock()
                env.prompt(step.data["message"])
                shift += env.clock() - before
                continue
            for mode, argv in commands(step, timeline):
                if mode == "spawn":
                    env.spawn(argv)
                elif env.run(argv) != 0:
                    raise DirectorError(f"step {step.index} failed ({_label(step)}): {shlex.join(argv)}")
    finally:
        if recorder is not None:
            recorder.stop()


class _Process:
    def __init__(self, argv: list[str]):
        self.proc = subprocess.Popen(argv, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

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


def _prompt(message: str) -> None:
    input(f"\n  CUE  {message}\n  Press Enter to continue... ")


def system_env() -> Env:
    return Env(run=_run, spawn=_Process, clock=time.monotonic, sleep=lambda s: time.sleep(max(0.0, s)), prompt=_prompt)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("timeline", help="timeline JSON file")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="print the resolved commands with their times")
    mode.add_argument("--record", metavar="OUT.mkv", help="record the screen with wf-recorder while running")
    args = parser.parse_args(argv)
    try:
        timeline = Timeline.load(args.timeline)
        if args.dry_run:
            print("\n".join(dry_run(timeline)))
            return 0
        run(timeline, system_env(), record=args.record)
    except DirectorError as error:
        print(f"director: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
