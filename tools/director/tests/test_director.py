import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import director  # noqa: E402

EXAMPLE = Path(__file__).resolve().parents[1] / "timelines" / "example.json"


class Fake:
    """Records every command and lets a test fail one or answer a cue."""

    def __init__(self, fail=None):
        self.calls = []
        self.prompts = []
        self.now = 0.0
        self.fail = fail or (lambda argv: False)
        self.recorder_stopped = False

    def run(self, argv):
        self.calls.append(("run", argv, round(self.now, 3)))
        return 1 if self.fail(argv) else 0

    def spawn(self, argv):
        self.calls.append(("spawn", argv, round(self.now, 3)))
        fake = self

        class Proc:
            def stop(self):
                fake.recorder_stopped = True

        return Proc()

    def clock(self):
        return self.now

    def sleep(self, seconds):
        self.now += max(0.0, seconds)

    def prompt(self, message):
        self.prompts.append(message)
        self.now += 5.0  # the human takes five seconds

    def env(self):
        return director.Env(run=self.run, spawn=self.spawn, clock=self.clock, sleep=self.sleep, prompt=self.prompt)


def load(data):
    return director.Timeline.from_dict(data)


def test_dry_run_of_the_example_lists_the_commands_in_order():
    timeline = director.Timeline.load(EXAMPLE)
    lines = director.dry_run(timeline)
    assert lines == [
        "   0.00  play play: playerctl -p crate play",
        "   1.50  notify: notify-send -a Crate Crate 'Now playing'",
        "   3.00  surface hub-widgets open: ryoku-shell hub open widgets",
        "   6.00  surface hub-widgets close: hyprctl dispatch closewindow class:ryoku-hub",
        "   7.00  cue: Open Controls with Super+Esc, then press Enter",
        "   9.00  wait",
    ]


def test_steps_run_on_schedule():
    fake = Fake()
    director.run(director.Timeline.load(EXAMPLE), fake.env())
    runs = [(argv[0], at) for kind, argv, at in fake.calls if kind == "run"]
    assert runs == [("playerctl", 0.0), ("notify-send", 1.5), ("ryoku-shell", 3.0), ("hyprctl", 6.0)]


def test_a_cue_pauses_and_shifts_the_rest_of_the_timeline():
    data = {
        "name": "t",
        "output": "t.mkv",
        "steps": [
            {"at": 0, "do": "cue", "message": "Open the launcher"},
            {"at": 1, "do": "notify", "title": "Crate", "body": "after"},
        ],
    }
    fake = Fake()
    director.run(load(data), fake.env())
    assert fake.prompts == ["Open the launcher"]
    # The human took 5 s, so the next step lands 1 s after the cue ends.
    assert fake.calls == [("run", ["notify-send", "-a", "Crate", "Crate", "after"], 6.0)]


def test_an_unknown_step_kind_is_rejected_when_loading():
    with pytest.raises(director.DirectorError, match="step 1: unknown do 'dance'"):
        load({"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "dance"}]})


def test_a_surface_missing_from_the_table_is_rejected_when_loading():
    with pytest.raises(director.DirectorError, match="unknown surface 'launcher'"):
        load({"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "surface", "name": "launcher", "action": "open"}]})


def test_steps_must_not_go_back_in_time():
    with pytest.raises(director.DirectorError, match="step 2 starts before step 1"):
        load({"name": "t", "output": "t.mkv", "steps": [{"at": 2, "do": "wait"}, {"at": 1, "do": "wait"}]})


def test_a_failing_command_aborts_and_stops_the_recorder():
    fake = Fake(fail=lambda argv: argv[0] == "ryoku-shell")
    with pytest.raises(director.DirectorError, match="step 3 failed .*ryoku-shell hub open widgets"):
        director.run(director.Timeline.load(EXAMPLE), fake.env(), record="take.mkv")
    assert fake.calls[0] == ("spawn", ["wf-recorder", "-r", "60", "-f", "take.mkv"], 0.0)
    assert fake.recorder_stopped
    # Nothing after the failing step ran.
    assert not any(argv[0] == "hyprctl" for _, argv, _ in fake.calls)


def test_recording_stops_the_recorder_after_the_last_step():
    fake = Fake()
    director.run(load({"name": "t", "output": "t.mkv", "steps": [{"at": 2, "do": "wait"}]}), fake.env(), record="t.mkv")
    assert fake.recorder_stopped
    assert fake.now == pytest.approx(2.0)


def test_window_launches_detached_and_places_with_hyprctl():
    data = {
        "name": "t",
        "output": "t.mkv",
        "steps": [
            {"at": 0, "do": "window", "run": ["crate-desktop"], "dispatch": ["movewindowpixel exact 80 80,class:crate"]},
        ],
    }
    fake = Fake()
    director.run(load(data), fake.env())
    assert fake.calls == [
        ("spawn", ["crate-desktop"], 0.0),
        ("run", ["hyprctl", "dispatch", "movewindowpixel", "exact 80 80,class:crate"], 0.0),
    ]


def test_pointer_moves_and_clicks_with_ydotool():
    data = {"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "pointer", "to": [100, 200], "click": True}]}
    assert director.dry_run(load(data)) == [
        "   0.00  pointer: ydotool mousemove --absolute -x 100 -y 200; ydotool click 0xC0",
    ]


def test_cli_dry_run_prints_the_plan(tmp_path, capsys):
    path = tmp_path / "t.json"
    path.write_text(json.dumps({"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "wait"}]}))
    assert director.main([str(path), "--dry-run"]) == 0
    assert "0.00  wait" in capsys.readouterr().out
