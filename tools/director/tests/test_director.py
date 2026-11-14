import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import director  # noqa: E402

EXAMPLE = Path(__file__).resolve().parents[1] / "timelines" / "example.json"


class Fake:
    """Records every command and lets a test fail one or answer a cue."""

    def __init__(self, fail=None, missing=(), recorder_dies=False):
        self.calls = []
        self.missing = set(missing)
        self.recorder_dies = recorder_dies
        self.prompts = []
        self.now = 0.0
        self.fail = fail or (lambda argv: False)
        self.recorder_stopped = False

    def run(self, argv):
        self.calls.append(("run", argv, round(self.now, 3)))
        return 1 if self.fail(argv) else 0

    def spawn(self, argv):
        if argv[0] in self.missing:
            raise FileNotFoundError(2, "No such file or directory", argv[0])
        self.calls.append(("spawn", argv, round(self.now, 3)))
        fake = self
        if argv[0] == "wf-recorder":
            Path(argv[argv.index("-f") + 1]).write_bytes(b"take")

        class Proc:
            def stop(self):
                fake.recorder_stopped = True

            def alive(self):
                return not fake.recorder_dies

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


def test_a_failing_command_aborts_and_stops_the_recorder(tmp_path):
    take = tmp_path / "take.mkv"
    fake = Fake(fail=lambda argv: argv[0] == "ryoku-shell")
    with pytest.raises(director.DirectorError, match="step 3 failed .*ryoku-shell hub open widgets"):
        director.run(director.Timeline.load(EXAMPLE), fake.env(), record=str(take))
    assert fake.calls[0] == ("spawn", ["wf-recorder", "-r", "60", "-f", str(take)], 0.0)
    assert fake.recorder_stopped
    # Nothing after the failing step ran.
    assert not any(argv[0] == "hyprctl" for _, argv, _ in fake.calls)


def test_recording_stops_the_recorder_after_the_last_step(tmp_path):
    take = tmp_path / "takes" / "t.mkv"
    fake = Fake()
    director.run(load({"name": "t", "output": "t.mkv", "steps": [{"at": 2, "do": "wait"}]}), fake.env(), record=str(take))
    assert fake.recorder_stopped
    assert take.is_file(), "a good take is kept, in a folder created for it"
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


def test_pointer_moves_with_hyprctl_and_clicks_with_ydotool():
    # Shell surfaces open on the monitor under the pointer, so a take parks it first.
    data = {"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "pointer", "to": [100, 200], "click": True}]}
    assert director.dry_run(load(data)) == [
        "   0.00  pointer: hyprctl dispatch movecursor 100 200; ydotool click 0xC0",
    ]


def test_cli_dry_run_prints_the_plan(tmp_path, capsys):
    path = tmp_path / "t.json"
    path.write_text(json.dumps({"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "wait"}]}))
    assert director.main([str(path), "--dry-run"]) == 0
    assert "0.00  wait" in capsys.readouterr().out


def test_a_failed_take_is_renamed_so_it_is_never_kept_as_good(tmp_path):
    take = tmp_path / "take.mkv"
    fake = Fake(fail=lambda argv: argv[0] == "ryoku-shell")
    with pytest.raises(director.DirectorError):
        director.run(director.Timeline.load(EXAMPLE), fake.env(), record=str(take))
    assert not take.exists()
    assert (tmp_path / "take.failed.mkv").is_file()


def test_a_missing_app_aborts_cleanly_and_discards_the_take(tmp_path):
    take = tmp_path / "take.mkv"
    data = {"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "window", "run": ["crate-desktop"]}]}
    fake = Fake(missing={"crate-desktop"})
    with pytest.raises(director.DirectorError, match="step 1 failed .*crate-desktop"):
        director.run(load(data), fake.env(), record=str(take))
    assert fake.recorder_stopped
    assert (tmp_path / "take.failed.mkv").is_file()


def test_a_recorder_that_died_stops_the_run_before_the_next_step(tmp_path):
    fake = Fake(recorder_dies=True)
    with pytest.raises(director.DirectorError, match="recorder stopped"):
        director.run(director.Timeline.load(EXAMPLE), fake.env(), record=str(tmp_path / "t.mkv"))
    assert [c for c in fake.calls if c[0] == "run"] == []


def test_interrupting_a_cue_discards_the_take(tmp_path):
    take = tmp_path / "take.mkv"
    fake = Fake()

    def interrupt(message):
        raise KeyboardInterrupt

    env = fake.env()
    env = director.Env(run=env.run, spawn=env.spawn, clock=env.clock, sleep=env.sleep, prompt=interrupt)
    with pytest.raises(KeyboardInterrupt):
        director.run(director.Timeline.load(EXAMPLE), env, record=str(take))
    assert (tmp_path / "take.failed.mkv").is_file()


def test_record_can_target_one_output_so_the_terminal_stays_out_of_frame(tmp_path):
    fake = Fake()
    director.run(load({"name": "t", "output": "t.mkv", "steps": []}), fake.env(), record=str(tmp_path / "t.mkv"), output="DP-1")
    assert fake.calls[0][1] == ["wf-recorder", "-r", "60", "-o", "DP-1", "-f", str(tmp_path / "t.mkv")]
