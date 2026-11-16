import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import director  # noqa: E402

EXAMPLE = Path(__file__).resolve().parents[1] / "timelines" / "example.json"


class Fake:
    """Records every command and lets a test fail one or answer a cue."""

    def __init__(self, fail=None, missing=(), recorder_dies=False, run_cost=0.0):
        self.run_cost = run_cost
        self.calls = []
        self.missing = set(missing)
        self.recorder_dies = recorder_dies
        self.prompts = []
        self.now = 0.0
        self.fail = fail or (lambda argv: False)
        self.recorder_stopped = False

    def run(self, argv):
        self.calls.append(("run", argv, round(self.now, 3)))
        self.now += self.run_cost
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


def test_key_step_presses_a_shortcut_with_real_keycodes():
    # Ryoku binds by keycode; wtype's virtual keymap starts at code 9 (Escape), so
    # shortcuts go through ydotool with evdev codes: Super (125) + W (17).
    data = {"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "key", "key": "w", "mods": ["super"]}]}
    assert director.dry_run(load(data)) == ["   0.00  key: ydotool key 125:1 17:1 17:0 125:0"]


def test_key_step_knows_named_keys_and_rejects_unknown_ones():
    data = {"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "key", "key": "Right"}]}
    assert director.dry_run(load(data)) == ["   0.00  key: ydotool key 106:1 106:0"]
    with pytest.raises(director.DirectorError, match="unknown key 'Hyper'"):
        load({"name": "t", "output": "t.mkv", "steps": [{"at": 0, "do": "key", "key": "Hyper"}]})


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
    assert marks["duration"] == 4.0
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


def test_a_click_that_opens_a_surface_marks_its_focus_for_the_cut(tmp_path):
    data = {
        "name": "t",
        "output": "t.mp4",
        "surfaces": {"crate-mark": {"focus": [0.36, 0.02, 0.21, 0.53]}},
        "steps": [
            {"at": 1, "do": "pointer", "to": [2377, 1460], "click": True, "opens": "crate-mark"},
            {"at": 3, "do": "pointer", "to": [2377, 1460], "click": True, "closes": "crate-mark"},
        ],
    }
    fake = Fake()
    director.run(load(data), fake.env(), record=str(tmp_path / "t.mp4"), geometry=EDP)
    events = json.loads((tmp_path / "t.marks.json").read_text())["events"]
    assert [e["kind"] for e in events] == ["open", "close"]
    assert events[0]["surface"] == "crate-mark" and events[0]["focus"] == [0.36, 0.02, 0.21, 0.53]
    assert events[1] == {"t": 3.0, "step": 2, "kind": "close", "surface": "crate-mark"}


def test_a_click_cannot_open_an_unknown_surface():
    with pytest.raises(director.DirectorError, match="unknown surface 'nope'"):
        load({"name": "t", "output": "t.mp4", "steps": [{"at": 0, "do": "pointer", "to": [1, 1], "click": True, "opens": "nope"}]})


def test_a_glide_that_clicks_marks_the_click_at_the_end_of_the_glide(tmp_path):
    data = {
        "name": "t",
        "output": "t.mp4",
        "surfaces": {"crate-mark": {"focus": [0.36, 0.02, 0.21, 0.53]}},
        "steps": [{"at": 1, "do": "pointer", "from": [0, 0], "to": [2377, 1460], "duration": 0.9, "click": True, "opens": "crate-mark"}],
    }
    fake = Fake()
    director.run(load(data), fake.env(), record=str(tmp_path / "t.mp4"), geometry=EDP)
    events = json.loads((tmp_path / "t.marks.json").read_text())["events"]
    assert events[0]["t"] == pytest.approx(1.9)


def test_a_slow_glide_drops_frames_to_land_on_time():
    # each movecursor costs 50 ms, three frames' worth at 60 fps
    data = {
        "name": "t",
        "output": "t.mp4",
        "steps": [
            {"at": 1, "do": "pointer", "from": [0, 0], "to": [100, 50], "duration": 0.5},
            {"at": 1.6, "do": "notify", "title": "C", "body": "b"},
        ],
    }
    fake = Fake(run_cost=0.05)
    director.run(load(data), fake.env())
    moves = [c for c in fake.calls if c[1][0] == "hyprctl"]
    assert moves[-1][1] == ["hyprctl", "dispatch", "hl.dsp.cursor.move({x=100,y=50})"], "always lands"
    assert moves[-1][2] <= 1.55, "the last move is not late"
    notify = [c for c in fake.calls if c[1][0] == "notify-send"][0]
    assert notify[2] == pytest.approx(1.6), "the next step keeps its time"


def test_window_steps_are_marked_for_a_reveal(tmp_path):
    data = {"name": "t", "output": "t.mp4", "steps": [{"at": 2, "do": "window", "run": ["kitty"]}]}
    fake = Fake()
    director.run(load(data), fake.env(), record=str(tmp_path / "t.mp4"), geometry=EDP)
    events = json.loads((tmp_path / "t.marks.json").read_text())["events"]
    assert events == [{"t": 2.0, "step": 1, "kind": "window"}]


def test_a_shortcut_that_opens_a_surface_marks_its_focus(tmp_path):
    data = {
        "name": "t",
        "output": "t.mp4",
        "surfaces": {"ask": {"focus": [0.33, 0.16, 0.34, 0.2]}},
        "steps": [
            {"at": 1, "do": "key", "key": "space", "mods": ["alt"], "opens": "ask"},
            {"at": 3, "do": "key", "key": "Escape", "closes": "ask"},
        ],
    }
    fake = Fake()
    director.run(load(data), fake.env(), record=str(tmp_path / "t.mp4"), geometry=EDP)
    events = json.loads((tmp_path / "t.marks.json").read_text())["events"]
    assert events == [
        {"t": 1.0, "step": 1, "kind": "open", "surface": "ask", "focus": [0.33, 0.16, 0.34, 0.2]},
        {"t": 3.0, "step": 2, "kind": "close", "surface": "ask"},
    ]


def test_a_surface_with_private_data_passes_its_redact_boxes_to_the_cut(tmp_path):
    boxes = [[0.776, 0.085, 0.138, 0.03], [0.776, 0.256, 0.138, 0.175]]
    data = {
        "name": "t",
        "output": "t.mp4",
        "surfaces": {"network": {"focus": [0.77, 0.02, 0.15, 0.5], "redact": boxes}},
        "steps": [
            {"at": 1, "do": "pointer", "to": [3355, 1460], "click": True, "opens": "network"},
            {"at": 3, "do": "pointer", "to": [3355, 1460], "click": True, "closes": "network"},
        ],
    }
    fake = Fake()
    director.run(load(data), fake.env(), record=str(tmp_path / "t.mp4"), geometry=EDP)
    events = json.loads((tmp_path / "t.marks.json").read_text())["events"]
    assert events[0]["redact"] == boxes
    assert "redact" not in events[1]


def test_record_can_capture_the_desktop_audio(tmp_path):
    fake = Fake()
    take = tmp_path / "t.mp4"
    director.run(load({"name": "t", "output": "t.mp4", "steps": []}), fake.env(), record=str(take), audio="sink.monitor")
    assert fake.calls[0][1] == ["wf-recorder", "-r", "60", "--audio=sink.monitor", "-f", str(take)]


def test_record_can_encode_on_a_vaapi_device(tmp_path):
    fake = Fake()
    take = tmp_path / "t.mp4"
    data = {"name": "t", "output": "t.mp4", "steps": []}
    director.run(load(data), fake.env(), record=str(take), vaapi="/dev/dri/renderD129")
    assert fake.calls[0][1] == [
        "wf-recorder", "-r", "60",
        "-c", "h264_vaapi", "-d", "/dev/dri/renderD129", "-p", "rc_mode=CQP", "-p", "qp=18",
        "-f", str(take),
    ]


def test_main_rejects_vaapi_without_record(capsys):
    with pytest.raises(SystemExit):
        director.main(["timeline.json", "--vaapi", "/dev/dri/renderD129"])
    assert "--vaapi needs --record" in capsys.readouterr().err


TEARDOWN = {
    "name": "t",
    "output": "t.mp4",
    "surfaces": {"x": {"open": ["boom"]}},
    "steps": [{"at": 0, "do": "notify", "title": "C", "body": "a"}],
    "teardown": [{"do": "notify", "title": "C", "body": "restore"}],
}


def test_teardown_runs_after_the_last_step():
    fake = Fake()
    director.run(load(TEARDOWN), fake.env())
    bodies = [argv[-1] for kind, argv, _ in fake.calls if argv[0] == "notify-send"]
    assert bodies == ["a", "restore"]


def test_teardown_runs_even_when_a_step_fails():
    data = dict(TEARDOWN, steps=[{"at": 0, "do": "surface", "name": "x", "action": "open"}])
    fake = Fake(fail=lambda argv: argv[0] == "boom")
    with pytest.raises(director.DirectorError, match="step 1 failed"):
        director.run(load(data), fake.env())
    assert any(argv[-1] == "restore" for _, argv, _ in fake.calls), "the setting is put back"


def test_a_failing_teardown_does_not_hide_the_step_failure():
    data = dict(TEARDOWN, steps=[{"at": 0, "do": "surface", "name": "x", "action": "open"}])
    fake = Fake(fail=lambda argv: argv[0] in ("boom", "notify-send"))
    with pytest.raises(director.DirectorError, match="step 1 failed"):
        director.run(load(data), fake.env())


def test_teardown_steps_are_validated_when_loading():
    with pytest.raises(director.DirectorError, match="teardown 1: unknown do 'dance'"):
        load(dict(TEARDOWN, teardown=[{"do": "dance"}]))


def test_nudge_moves_the_real_pointer_a_hair_and_back_so_hover_fires():
    # hyprctl warps the cursor without a motion event; a surface that moves under a
    # still pointer (Ryogami's Duel cards) only notices a real device motion
    data = {"name": "t", "output": "t.mp4", "steps": [{"at": 0, "do": "nudge"}]}
    assert director.dry_run(load(data)) == [
        "   0.00  nudge: ydotool mousemove -x 4 -y 0; ydotool mousemove -x -4 -y 0",
    ]


def test_a_caption_needs_text_and_runs_nothing():
    with pytest.raises(director.DirectorError, match="step 1: caption needs 'text'"):
        load({"name": "t", "output": "t.mp4", "steps": [{"at": 0, "do": "caption", "eyebrow": "Crate"}]})
    with pytest.raises(director.DirectorError, match="caption 'eyebrow' must be a string"):
        load({"name": "t", "output": "t.mp4", "steps": [{"at": 0, "do": "caption", "text": "x", "eyebrow": 3}]})
    fake = Fake()
    director.run(load({"name": "t", "output": "t.mp4", "steps": [{"at": 1, "do": "caption", "text": "x"}]}), fake.env())
    assert fake.calls == []


def test_a_caption_is_not_a_teardown_step():
    with pytest.raises(director.DirectorError, match="teardown 1: unknown do 'caption'"):
        load(dict(TEARDOWN, teardown=[{"do": "caption", "text": "x"}]))


def test_dry_run_prints_a_caption_with_its_eyebrow_or_as_a_clear():
    data = {
        "name": "t",
        "output": "t.mp4",
        "steps": [
            {"at": 0, "do": "caption", "eyebrow": "Crate for Ryoku", "text": "One glass, every surface"},
            {"at": 2, "do": "caption", "text": "No eyebrow"},
            {"at": 4, "do": "caption", "text": ""},
        ],
    }
    assert director.dry_run(load(data)) == [
        "   0.00  caption: Crate for Ryoku | One glass, every surface",
        "   2.00  caption: No eyebrow",
        "   4.00  caption: (clear)",
    ]


def test_captions_are_marked_for_the_cut_including_the_clear(tmp_path):
    data = {
        "name": "t",
        "output": "t.mp4",
        "steps": [
            {"at": 1, "do": "caption", "eyebrow": "Controls", "text": "Everything in one glass"},
            {"at": 3, "do": "caption", "text": "Plain"},
            {"at": 5, "do": "caption", "text": ""},
        ],
    }
    fake = Fake()
    director.run(load(data), fake.env(), record=str(tmp_path / "t.mp4"), geometry=EDP)
    events = json.loads((tmp_path / "t.marks.json").read_text())["events"]
    assert events == [
        {"t": 1.0, "step": 1, "kind": "caption", "text": "Everything in one glass", "eyebrow": "Controls"},
        {"t": 3.0, "step": 2, "kind": "caption", "text": "Plain"},
        {"t": 5.0, "step": 3, "kind": "caption", "text": ""},
    ]
