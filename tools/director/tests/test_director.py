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
            {"at": 0, "do": "window", "run": ["crate-desktop"], "dispatch": ['hl.dsp.window.fullscreen()']},
        ],
    }
    fake = Fake()
    director.run(load(data), fake.env())
    assert fake.calls == [
        ("spawn", ["crate-desktop"], 0.0),
        ("run", ["hyprctl", "dispatch", "hl.dsp.window.fullscreen()"], 0.0),
    ]


def test_pointer_moves_with_hyprctl_and_clicks_with_ydotool():
    # Shell surfaces open on the monitor under the pointer, so a take parks it first.
    data = {"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "pointer", "to": [100, 200], "click": True}]}
    assert director.dry_run(load(data)) == [
        "   0.00  pointer: hyprctl dispatch 'hl.dsp.cursor.move({x=100,y=200})'; ydotool click 0xC0",
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


def test_type_step_types_text_with_wtype():
    data = {"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "type", "text": "cr nitzer"}]}
    assert director.dry_run(load(data)) == ["   0.00  type: wtype -d 60 'cr nitzer'"]


def test_key_step_presses_a_shortcut_with_wtype():
    data = {"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "key", "key": "Escape", "mods": ["logo"]}]}
    assert director.dry_run(load(data)) == ["   0.00  key: wtype -M logo -k Escape -m logo"]


def test_a_pointer_glide_moves_in_eased_frames_over_its_duration():
    data = {
        "name": "t",
        "output": "t.mkv",
        "steps": [{"at": 1, "do": "pointer", "from": [0, 0], "to": [100, 50], "duration": 0.5}],
    }
    fake = Fake()
    director.run(load(data), fake.env())
    moves = [(argv, at) for kind, argv, at in fake.calls if kind == "run"]
    assert len(moves) == 30  # 60 fps for half a second
    assert moves[0][0] == ["hyprctl", "dispatch", "hl.dsp.cursor.move({x=0,y=0})"]
    assert moves[-1][0] == ["hyprctl", "dispatch", "hl.dsp.cursor.move({x=100,y=50})"]
    assert moves[0][1] == 1.0 and moves[-1][1] == pytest.approx(1.5, abs=0.02)
    xs = [int(argv[2].split("x=")[1].split(",")[0]) for argv, _ in moves]
    assert xs == sorted(xs), "the glide never goes backwards"
    assert xs[1] - xs[0] < xs[15] - xs[14], "eased: slow at the start, faster in the middle"


def test_a_glide_needs_a_start_point():
    with pytest.raises(director.DirectorError, match="glide needs 'from'"):
        load({"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "pointer", "to": [1, 1], "duration": 1}]})


EDP = {"name": "eDP-1", "x": 1408, "y": 1440, "width": 3840, "height": 2400, "scale": 1.6}


def test_a_good_take_writes_marks_for_the_cut(tmp_path):
    take = tmp_path / "t.mkv"
    data = {
        "name": "t",
        "output": "t.mkv",
        "surfaces": {
            "launcher": {"open": ["a"], "close": ["b"], "focus": [0.3, 0.05, 0.4, 0.3]},
        },
        "steps": [
            {"at": 1, "do": "surface", "name": "launcher", "action": "open"},
            {"at": 2, "do": "pointer", "to": [1408 + 1200, 1440 + 750], "click": True},
            {"at": 4, "do": "surface", "name": "launcher", "action": "close"},
        ],
    }
    fake = Fake()
    director.run(load(data), fake.env(), record=str(take), geometry=EDP)
    marks = json.loads((tmp_path / "t.marks.json").read_text())
    assert marks["output"] == EDP
    assert marks["events"] == [
        {"t": 1.0, "step": 1, "kind": "open", "surface": "launcher", "focus": [0.3, 0.05, 0.4, 0.3]},
        {"t": 2.0, "step": 2, "kind": "click", "point": [0.5, 0.5]},
        {"t": 4.0, "step": 3, "kind": "close", "surface": "launcher"},
    ]


def test_marks_keep_the_real_time_after_a_cue(tmp_path):
    data = {
        "name": "t",
        "output": "t.mkv",
        "steps": [{"at": 0, "do": "cue", "message": "x"}, {"at": 1, "do": "notify", "title": "C", "body": "b"}],
    }
    fake = Fake()
    director.run(load(data), fake.env(), record=str(tmp_path / "t.mkv"), geometry=EDP)
    marks = json.loads((tmp_path / "t.marks.json").read_text())
    assert marks["events"] == [{"t": 6.0, "step": 2, "kind": "notify"}]


def test_a_failed_take_writes_no_marks(tmp_path):
    fake = Fake(fail=lambda argv: argv[0] == "ryoku-shell")
    with pytest.raises(director.DirectorError):
        director.run(director.Timeline.load(EXAMPLE), fake.env(), record=str(tmp_path / "t.mkv"), geometry=EDP)
    assert not (tmp_path / "t.marks.json").exists()
