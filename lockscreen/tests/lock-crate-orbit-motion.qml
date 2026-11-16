import QtQuick
import QtQuick.Window
import Quickshell
import Ryoku.Ui.Singletons
import "harness"
import "harness/SkinChecks.js" as Checks

// crate/orbit motion: the minute and seconds rings follow real time to the millisecond, the
// current second and minute are spotlit, Enter winds the rings up while PAM works, a failure
// settles them back on real time, a success (typed or sensor) plays the reveal, and reduced
// motion keeps everything still. THEME_CONF holds orbit's theme.conf, which must hold the lock
// surface for at least as long as the reveal runs.
ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/crate/orbit/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false; hostName: "crate-host" }
    FakeUserModel { id: users }
    Component.onCompleted: users.setUsers(["diego"])

    Window {
        visible: true; width: 1920; height: 1200
        TestHost { id: host; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: users }
    }

    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }
    function find(i, n) { return Checks.find(i, n); }
    function eq(a, b, what) { return Checks.eq({ fail: root.fail }, a, b, what); }
    function near(a, b, tol, what) {
        if (Math.abs(a - b) > tol) { fail(what + ": expected " + b + " (+-" + tol + "), got " + a); return false; }
        return true;
    }
    // Same angle on the dial, whatever the number of whole turns between them.
    function sameAngle(a, b, tol, what) {
        var d = ((((a - b) % 360) + 540) % 360) - 180;
        if (Math.abs(d) > tol) { fail(what + ": " + a + " is not at " + b + " (mod 360)"); return false; }
        return true;
    }
    function cyanHi(item) { return String(item.color).toLowerCase() === "#67e8f9"; }
    function conf(key) {
        var m = new RegExp("^" + key + "=(.*)$", "m").exec(String(Quickshell.env("THEME_CONF")));
        return m ? m[1].trim() : "";
    }

    // Steps run one after another; each returns the delay before the next, or -1 after a failure.
    property int step: 0
    property var t0: 0
    readonly property var steps: ["pinned", "live", "liveSecondLater", "windupStart", "windupFull", "failed", "retyped", "stillWinding", "settled",
        "succeed", "revealed", "unlockFailed", "restoreTimer", "restoredByTimer", "keyPin", "keyTouch", "keyTouchSettled",
        "keyTimeout", "keyTimeoutSettled", "sensor", "sensorRevealed", "reduced", "reducedLater", "done"]
    Timer {
        id: runner
        interval: 700; running: true
        onTriggered: {
            if (!host.item) return fail("theme did not load");
            var next = root[root.steps[root.step++]]();
            if (next >= 0) { runner.interval = next; runner.start(); }
        }
    }

    function o() { return host.item; }
    function dial() { return find(host.item, "orbitDial"); }

    function pinned() {
        var it = o(), d = dial();
        if (!d) return fail("no orbitDial"), -1;
        it.liveClock = false;
        it.clockLocale = Qt.locale("en_US");
        it.now = new Date(2026, 10, 16, 16, 42, 7, 350);
        // Seconds ring: 7.35 s into the minute; minute ring: 42 min 7.35 s into the hour.
        if (!near(d.secondTargetRotation, -(7350 * 360 / 60000), 1e-6, "seconds target at :07.350")) return -1;
        if (!near(d.secondRotation, d.secondTargetRotation, 1e-6, "seconds ring on its target")) return -1;
        if (!near(d.targetRotation, -((42 * 60000 + 7350) * 360 / 3600000), 1e-6, "minute target at 42:07.350")) return -1;
        if (!near(d.ringRotation, d.targetRotation, 1e-6, "minute ring on its target")) return -1;
        if (!eq(d.secondTickCount, 60, "seconds ticks")) return -1;
        // Spotlight: the current second and minute in cyan-hi, their neighbours not.
        var ss = find(d, "secondSpot"), ms = find(d, "minuteSpot");
        if (!ss || !ms) return fail("no spotlight labels"), -1;
        if (!eq(ss.text, "07", "second spotlight text") || !eq(ms.text, "42", "minute spotlight text")) return -1;
        if (!cyanHi(ss) || !cyanHi(ms)) return fail("spotlight is not cyan-hi"), -1;
        if (!eq(ss.parent.rotation, 42, "second spotlight angle on its ring")) return -1;
        if (!eq(ms.parent.rotation, 252, "minute spotlight angle on its ring")) return -1;
        if (!cyanHi(find(d, "secondTick7"))) return fail("current second tick is not cyan-hi"), -1;
        if (cyanHi(find(d, "secondTick8")) || cyanHi(find(d, "secondTick6"))) return fail("a neighbour second tick is cyan-hi"), -1;
        if (!cyanHi(find(d, "tick42"))) return fail("current minute tick is not cyan-hi"), -1;
        // Ticks and labels are made once: the spotlight moves, the rings never rebuild.
        root.secondTick0 = find(d, "secondTick0");
        it.now = new Date(2026, 10, 16, 16, 42, 9, 0);
        if (!eq(ss.text, "09", "second spotlight follows the clock")) return -1;
        if (find(d, "secondTick0") !== root.secondTick0) return fail("seconds ring re-created its ticks"), -1;
        // The hour sits inside the minute ring, smaller than the ring it is in.
        var hour = find(it, "hourText");
        if (hour.font.pixelSize > d.minuteRadius * 0.75) return fail("hour " + hour.font.pixelSize + " too big for the minute ring " + d.minuteRadius), -1;
        if (d.secondRadius <= d.minuteRadius) return fail("seconds ring is not outside the minute ring"), -1;
        // The readout window holds the current minute and second as fixed text, wherever the
        // rings have turned them.
        for (const t of [[0, 0, 0], [30, 0, 0], [50, 0, 0], [44, 59, 999], [7, 0, 900]]) {
            it.now = new Date(2026, 10, 16, 16, t[0], t[1], t[2]);
            if (!readoutShows(it, t[0], t[1], "readout at " + t.join(":"))) return -1;
        }
        it.now = new Date(2026, 10, 16, 16, 42, 7, 350);
        it.liveClock = true;
        return 250;
    }
    function two(n) { return (n < 10 ? "0" : "") + n; }
    function readoutShows(it, mm, ss, what) {
        var win = find(it, "orbitPointer"), m = find(it, "minuteReadout"), sec = find(it, "secondReadout");
        if (!win || !m || !sec) return fail(what + ": no readout window or text"), false;
        if (!eq(m.text, two(mm), what + " minute") || !eq(sec.text, two(ss), what + " second")) return false;
        if (!cyanHi(m)) return fail(what + ": minute readout is not cyan-hi"), false;
        if (m.font.family !== it.monoFamily || sec.font.family !== it.monoFamily) return fail(what + ": readout is not mono"), false;
        var w = Checks.rect(win);
        for (const t of [m, sec]) {
            var r = Checks.rect(t);
            if (r.x < w.x || r.y < w.y || r.x + r.w > w.x + w.w || r.y + r.h > w.y + w.h)
                return fail(what + ": " + t.objectName + " " + JSON.stringify(r) + " leaves the window " + JSON.stringify(w)), false;
        }
        return true;
    }
    property var secondTick0: null
    property real liveAngle: 0
    property real liveAt: 0
    // Live: the rings turn smoothly from real time, between whole seconds too.
    function live() {
        var d = dial(), n = new Date();
        var expect = -((n.getSeconds() * 1000 + n.getMilliseconds()) * 360 / 60000);
        if (!sameAngle(d.secondRotation, expect, 1.5, "live seconds ring")) return -1;
        root.liveAngle = d.secondRotation;
        root.liveAt = Date.now();
        return 600;
    }
    function liveSecondLater() {
        var d = dial();
        var moved = ((((root.liveAngle - d.secondRotation) % 360) + 360) % 360);
        var expect = (Date.now() - root.liveAt) * 360 / 60000;
        // About 3.6 degrees in 600 ms; a ring stepping once a second would be 0 or 6 off.
        if (!near(moved, expect, 0.5, "seconds ring turned continuously")) return -1;
        o().liveClock = false;
        o().now = new Date(2026, 10, 16, 16, 42, 7, 350);
        return 0;
    }

    // Enter with a password winds the rings up at once, before PAM answers.
    function windupStart() {
        var it = o(), f = find(it, "passwordField");
        if (!eq(it.windupProgress, 0, "windup before Enter")) return -1;
        f.text = "bad";
        f.input.accepted();
        if (!eq(Checks.count(fake, "login"), 1, "login on Enter")) return -1;
        root.t0 = Date.now();
        return 250;
    }
    function windupFull() {
        var it = o();
        if (!(it.windupProgress > 0)) return fail("no windup progress 250 ms after Enter: " + it.windupProgress + " " + it.motionState), -1;
        if (!eq(it.motionState, "windup", "motion state after Enter")) return -1;
        return Math.max(0, it.windupMs + 150 - (Date.now() - root.t0));
    }
    function failed() {
        var it = o(), d = dial();
        if (!near(it.windupProgress, 1, 1e-6, "windup progress at the end of the ramp")) return -1;
        if (!(Math.abs(d.spin) > 1)) return fail("rings did not spin up"), -1;
        if (!(find(d, "orbitStreaks").opacity > 0.5)) return fail("no streaks at full windup"), -1;
        fake.loginFailed();
        if (!eq(find(it, "accessDenied").visible, true, "access denied after the failure")) return -1;
        if (it.motionState !== "settling") return fail("failure did not settle the windup: " + it.motionState), -1;
        return 100;
    }
    // Enter again mid-settle winds up from there; the abandoned settle must not stop it later.
    function retyped() {
        var it = o(), f = find(it, "passwordField");
        f.text = "again";
        f.input.accepted();
        if (!eq(it.motionState, "windup", "motion state after Enter during a settle")) return -1;
        return 1400;
    }
    function stillWinding() {
        var it = o();
        if (!eq(it.motionState, "windup", "windup outlives the abandoned settle")) return -1;
        if (!(it.windupProgress > 0.5)) return fail("windup stalled after the abandoned settle: " + it.windupProgress), -1;
        fake.loginFailed();
        return 1400;
    }
    // Back on real time: no windup, no extra spin, the rings on the clock again.
    function settled() {
        var it = o(), d = dial();
        if (!eq(it.windupProgress, 0, "windup after the failure settled")) return -1;
        if (!eq(it.motionState, "idle", "motion state after settling")) return -1;
        if (!eq(d.spin, 0, "spin after settling")) return -1;
        if (!near(d.secondRotation, d.secondTargetRotation, 1e-6, "seconds ring back on real time")) return -1;
        if (!near(d.ringRotation, d.targetRotation, 1e-6, "minute ring back on real time")) return -1;
        if (!eq(find(d, "orbitStreaks").opacity, 0, "streaks after settling")) return -1;
        return 0;
    }

    // A typed success plays the reveal: the UI fades and the dial scales out.
    function succeed() {
        var it = o(), f = find(it, "passwordField");
        f.text = "good";
        f.input.accepted();
        fake.loginSucceeded();
        if (!eq(it.motionState, "reveal", "motion state on success")) return -1;
        return it.revealMs + 120;
    }
    function revealed() {
        var it = o(), stage = find(it, "orbitStage");
        if (!stage) return fail("no orbitStage"), -1;
        if (!eq(it.revealProgress, 1, "reveal progress")) return -1;
        if (!eq(stage.opacity, 0, "stage opacity after the reveal")) return -1;
        if (!(it.dialScale > 1.05)) return fail("dial did not scale out: " + it.dialScale), -1;
        // The lock shell holds the surface through the reveal: theme.conf says for how long.
        var hold = Number(conf("unlockRevealMs")), sensorHold = Number(conf("unlockSensorRevealMs"));
        if (!(hold >= it.revealMs + 100)) return fail("unlockRevealMs " + hold + " shorter than the reveal " + it.revealMs), -1;
        if (!(sensorHold >= it.sensorWindupMs + it.revealMs + 100))
            return fail("unlockSensorRevealMs " + sensorHold + " shorter than the sensor windup + reveal"), -1;
        // A re-shown lock surface (the unlock did not happen) brings the UI back.
        fake.surfaceRevealed();
        if (!eq(stage.opacity, 1, "stage opacity after surfaceRevealed")) return -1;
        if (!eq(it.motionState, "idle", "motion state after surfaceRevealed")) return -1;
        if (!eq(dial().spin, 0, "spin after surfaceRevealed")) return -1;
        return 0;
    }

    // PAM said yes but the shell could not unlock: it reports loginFailed. The UI is back at once,
    // with ACCESS DENIED, not left invisible until a timer.
    function unlockFailed() {
        var it = o(), f = find(it, "passwordField");
        f.text = "good";
        f.input.accepted();
        fake.loginSucceeded();
        return it.revealMs + 120;
    }
    function restoreTimer() {
        var it = o(), stage = find(it, "orbitStage");
        if (!eq(stage.opacity, 0, "stage hidden after the reveal")) return -1;
        fake.loginFailed();
        if (!eq(stage.opacity, 1, "stage opacity after a failed unlock")) return -1;
        if (!eq(it.motionState, "idle", "motion state after a failed unlock")) return -1;
        if (!eq(find(it, "accessDenied").visible, true, "access denied after a failed unlock")) return -1;
        if (!eq(dial().spin, 0, "spin after a failed unlock")) return -1;
        // Nothing arrives at all: the fallback timer brings the lock back.
        it.revealRestoreMs = 300;
        var f = find(it, "passwordField");
        f.text = "good";
        f.input.accepted();
        fake.loginSucceeded();
        return it.revealMs + 400;
    }
    function restoredByTimer() {
        var it = o();
        if (!eq(it.motionState, "idle", "motion state after the restore timer")) return -1;
        if (!eq(find(it, "orbitStage").opacity, 1, "stage opacity after the restore timer")) return -1;
        it.revealRestoreMs = it.sensorWindupMs + it.revealMs + 4000;
        return 0;
    }

    // Security key: a PIN is not wound up for; a touch prompt or a timeout settles a windup.
    function keyPin() {
        var it = o(), f = find(it, "passwordField");
        fake.requestKeyState("pin");
        f.text = "1234";
        f.input.accepted();
        if (!eq(Checks.count(fake, "loginKeyPin") > 0, true, "PIN sent")) return -1;
        if (!eq(it.motionState, "idle", "no windup for a PIN")) return -1;
        if (!eq(it.windupProgress, 0, "no windup progress for a PIN")) return -1;
        fake.loginFailed();
        fake.usePassword();
        f.text = "pw";
        f.input.accepted();
        if (!eq(it.motionState, "windup", "windup for a password")) return -1;
        return 300;
    }
    function keyTouch() {
        var it = o();
        fake.requestKeyState("touch");
        if (!eq(it.motionState, "settling", "touch prompt settles the windup")) return -1;
        return 1400;
    }
    function keyTouchSettled() {
        var it = o(), f = find(it, "passwordField");
        if (!eq(it.motionState, "idle", "settled after the touch prompt")) return -1;
        fake.usePassword();
        fake.loginFailed();
        f.text = "pw";
        f.input.accepted();
        if (!eq(it.motionState, "windup", "windup before the key timeout")) return -1;
        return 300;
    }
    function keyTimeout() {
        var it = o();
        fake.keyTimedOut();
        if (!eq(it.motionState, "settling", "key timeout settles the windup")) return -1;
        return 1400;
    }
    function keyTimeoutSettled() {
        var it = o();
        if (!eq(it.motionState, "idle", "settled after the key timeout")) return -1;
        if (!eq(dial().spin, 0, "spin after the key timeout")) return -1;
        fake.loginFailed();
        return 0;
    }

    // A sensor win: a short windup, then the same reveal. Nothing typed, no second login.
    function sensor() {
        var it = o();
        var logins = Checks.count(fake, "login");
        fake.fingerprintUnlock = true;
        fake.loginSucceeded();
        if (!eq(it.motionState, "windup", "motion state on a sensor win")) return -1;
        root.t0 = Date.now();
        root.sensorLogins = logins;
        return it.sensorWindupMs + it.revealMs + 150;
    }
    property int sensorLogins: 0
    function sensorRevealed() {
        var it = o();
        if (!eq(it.motionState, "reveal", "sensor win ends in the reveal")) return -1;
        if (!eq(find(it, "orbitStage").opacity, 0, "stage opacity after the sensor reveal")) return -1;
        if (!eq(Checks.count(fake, "login"), root.sensorLogins, "login calls on a sensor win")) return -1;
        fake.fingerprintUnlock = false;
        fake.surfaceRevealed();

        // Reduced motion: the rings stand on the real position, Enter winds nothing up.
        // The accessibility setting holds whether or not the shell's Crate controls are on.
        Tokens.controlsCrate = false;
        Tokens.reduceMotion = true;
        if (!eq(it.reduceMotion, true, "reduceMotion from Tokens with controlsCrate off")) return -1;
        Tokens.controlsCrate = true;
        if (!eq(it.reduceMotion, true, "reduceMotion from Tokens with controlsCrate on")) return -1;
        Tokens.controlsCrate = false;
        it.liveClock = true;
        var f = find(it, "passwordField");
        f.text = "bad";
        f.input.accepted();
        return 300;
    }
    function reduced() {
        var it = o(), d = dial();
        if (!eq(it.windupProgress, 0, "windup under reduced motion")) return -1;
        if (!eq(it.motionState, "idle", "motion state under reduced motion")) return -1;
        if (!eq(d.spin, 0, "spin under reduced motion")) return -1;
        // Still: not sampled per frame, and standing on the clock's whole second.
        if (!eq(d.driving, false, "dial driving under reduced motion")) return -1;
        it.liveClock = false;
        it.now = new Date(2026, 10, 16, 16, 42, 7, 650);
        if (!near(d.secondRotation, -(7000 * 360 / 60000), 1e-6, "reduced-motion seconds ring on the whole second")) return -1;
        if (!near(d.ringRotation, -((42 * 60000 + 7000) * 360 / 3600000), 1e-6, "reduced-motion minute ring on the whole second")) return -1;
        fake.loginFailed();
        fake.loginSucceeded();
        if (!eq(it.dialScale, 1, "no scale under reduced motion")) return -1;
        return it.revealMs + 120;
    }
    function reducedLater() {
        var it = o();
        if (!eq(find(it, "orbitStage").opacity, 0, "plain fade under reduced motion")) return -1;
        if (!eq(it.dialScale, 1, "no scale under reduced motion after the fade")) return -1;
        if (!eq(dial().spin, 0, "no spin under reduced motion")) return -1;
        return 0;
    }
    function done() {
        console.log("PASS: orbit rings, spotlight, windup, settle and reveal");
        Qt.quit();
        return -1;
    }
}
