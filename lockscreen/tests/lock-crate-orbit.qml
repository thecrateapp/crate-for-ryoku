import QtQuick
import QtQuick.Window
import Quickshell
import "harness"
import "harness/SkinChecks.js" as Checks

// crate/orbit specifics: the minute dial, the date, the right-aligned sign-in and its layout.
// The behaviours both skins share run from SkinChecks.js in the other lock-crate-* tests.
ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/crate/orbit/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false; hostName: "crate-host" }
    FakeUserModel { id: users }
    FakePlayer { id: player; title: "Blending"; artist: "High Vis"; position: 50; length: 200; playing: true }
    Component.onCompleted: users.setUsers(["diego"])

    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: host; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: users }
    }
    Window {
        visible: true; width: 3840; height: 2400
        TestHost { id: big; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: users }
    }
    Window {
        visible: true; width: 1024; height: 600
        TestHost { id: small; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: users }
    }

    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }
    function find(i, n) { return Checks.find(i, n); }
    function eq(a, b, what) { return Checks.eq({ fail: root.fail }, a, b, what); }
    // Any object whose name says it is orbital's white blast or its sparks (orbit winds up with
    // cyan streaks instead; see lock-crate-orbit-motion).
    function strays(item) {
        if (/blast|spark/i.test(String(item.objectName))) return item.objectName;
        for (var i = 0; i < item.children.length; i++) {
            var r = strays(item.children[i]);
            if (r) return r;
        }
        return "";
    }

    // The readout window holds the given minute (cyan-hi, mono) as fixed text inside its bounds.
    function windowShows(o, mm, what) {
        var t = find(o, "minuteReadout"), win = find(o, "orbitPointer");
        if (!t || !win) return fail(what + ": no minuteReadout or orbitPointer"), false;
        if (!eq(t.text, mm, what)) return false;
        if (!eq(String(t.color).toLowerCase(), "#67e8f9", what + " colour")) return false;
        if (!eq(t.font.family, o.monoFamily, what + " family")) return false;
        var r = Checks.rect(t), w = Checks.rect(win);
        if (r.x < w.x || r.y < w.y || r.x + r.w > w.x + w.w || r.y + r.h > w.y + w.h)
            return fail(what + ": readout " + JSON.stringify(r) + " leaves the window " + JSON.stringify(w)), false;
        return true;
    }

    function layoutCheck(o, label) {
        if (!o.fontsReady) return fail(label + ": fonts not ready"), false;
        if (Math.abs(o.uiScale - o.height / 1200) > 1e-9) return fail(label + ": uiScale is not height / 1200"), false;
        var names = ["orbitDial", "dateBlock", "authColumn", "nowPlaying", "powerRow"];
        var r = {};
        for (var i = 0; i < names.length; i++) {
            var it = find(o, names[i]);
            if (!it) return fail(label + ": no " + names[i]), false;
            r[names[i]] = Checks.rect(it);
            // The dial bleeds off the left edge on purpose.
            if (names[i] !== "orbitDial" && !Checks.within(r[names[i]], o)) return fail(label + ": " + names[i] + " leaves the screen"), false;
        }
        var d = r.orbitDial, h = Checks.rect(find(o, "hourText"));
        if (h.x < d.x || h.y < d.y || h.x + h.w > d.x + d.w || h.y + h.h > d.y + d.h) return fail(label + ": hour leaves the dial"), false;
        if (d.x >= 0) return fail(label + ": dial does not bleed off the left edge"), false;
        if (d.x + d.w <= 0) return fail(label + ": dial is entirely off screen"), false;
        if (d.y < 0 || d.y + d.h > o.height) return fail(label + ": dial leaves the screen vertically"), false;
        for (var a = 0; a < names.length; a++)
            for (var b = a + 1; b < names.length; b++)
                if (Checks.intersects(r[names[a]], r[names[b]])) return fail(label + ": " + names[a] + " overlaps " + names[b]), false;
        if (find(o, "nowPlaying").compact !== true) return fail(label + ": now playing is not compact"), false;
        if (!windowShows(o, o.clockLocale.toString(o.now, "mm"), label + ": reading window")) return false;
        return true;
    }

    Timer {
        interval: 700; running: true
        onTriggered: {
            if (!host.item || !big.item || !small.item) return fail("theme did not load");
            var o = host.item;
            for (const h of [host.item, big.item, small.item]) {
                h.liveClock = false;
                h.clockLocale = Qt.locale("en_US");
                h.now = new Date(2026, 11, 6, 23, 5, 0);
            }
            var s = strays(o);
            if (s) return fail("orbital leftover object: " + s);
            // The dial animates its turn: check its angle once it has settled.
            main.start();
        }
    }
    // First paint: the dial is already on its real minute, never spinning in from zero.
    Timer {
        interval: 40; running: true
        onTriggered: {
            var dial = find(host.item, "orbitDial");
            if (!dial) return fail("no orbitDial at first paint");
            var d = (((dial.ringRotation - dial.targetRotation) % 360) + 360) % 360;
            if (d > 0.01 && d < 359.99) return fail("dial not at target on first paint: " + dial.ringRotation + " vs " + dial.targetRotation);
        }
    }
    Timer {
        id: main
        interval: 900
        onTriggered: {
            var o = host.item;

            // Dial: turns with the real minutes, current minute in cyan-hi, 60 ticks.
            var dial = find(o, "orbitDial");
            if (!dial) return fail("no orbitDial");
            if (!eq(dial.ringRotation, -30, "dial rotation at :05")) return;
            if (!eq(Math.round(dial.ringRotation), Math.round(-(5 / 60) * 360), "dial rotation formula")) return;
            if (!eq(dial.tickCount, 60, "tick count")) return;
            if (!eq(String(find(dial, "tick5").color).toLowerCase(), "#67e8f9", "current minute tick")) return;
            if (String(find(dial, "tick6").color).toLowerCase() === "#67e8f9") return fail("other tick is also cyan-hi");
            if (!eq(find(dial, "dialNumber10").text, "10", "major number")) return;
            if (find(dial, "dialNumber11")) return fail("non-major tick has a number");

            // Hour and minute.
            // The reading window is the minute's only readout: no second minute label beside it.
            if (find(o, "minuteLabel")) return fail("the minute is repeated beside the reading window");
            if (!windowShows(o, "05", "minute in the window at :05")) return;
            var hour = find(o, "hourText");
            o.clock24h = true;
            if (!eq(hour.text, "23", "24 h hour")) return;
            if (!eq(hour.font.family, o.displayFamily, "hour family")) return;
            if (!eq(hour.font.weight, 800, "hour weight")) return;
            var ap = find(o, "clockAmPm");
            if (ap.visible) return fail("AM/PM shown in 24 h");
            o.clock24h = false;
            if (!eq(hour.text, "11", "12 h hour")) return;
            if (!eq(ap.text, "PM", "AM/PM") || !ap.visible) return;
            o.clock24h = true;

            // Date: weekday in the display family, uppercase; the rest mono.
            var wd = find(o, "dateWeekday"), rest = find(o, "dateRest");
            if (!eq(wd.text, "SUNDAY", "weekday")) return;
            if (!eq(rest.text, "06 DEC 2026", "date rest")) return;
            if (!eq(wd.font.family, o.displayFamily, "weekday family")) return;
            if (!eq(rest.font.family, o.monoFamily, "date family")) return;

            // Power row separators: hairline, one pixel.
            for (const n of ["powerSep0", "powerSep1"]) {
                var sep = find(o, n);
                if (!sep) return fail("no " + n);
                if (!eq(sep.width, 1, n + " width")) return;
                if (!eq(String(sep.color).toLowerCase(), String(Qt.rgba(241 / 255, 245 / 255, 249 / 255, 0.1)).toLowerCase(), n + " colour")) return;
            }

            // Sign-in column: right-aligned, with the Unlock action and the access denied line.
            var col = find(o, "authColumn");
            if (!eq(Math.round(Checks.rect(col).x + col.width), Math.round(o.width - o.margin), "column right edge")) return;
            var name = find(o, "userSwitchLink");
            if (!eq(name.label.horizontalAlignment, Text.AlignRight, "user name alignment")) return;
            if (!eq(name.label.font.family, o.monoFamily, "user name family")) return;
            var field = find(o, "passwordField");
            var fr = Checks.rect(field);
            if (!eq(Math.round(fr.x + fr.w), Math.round(o.width - o.margin), "field right edge")) return;
            if (find(o, "errorLine")) return fail("orbit must not have a second error line");
            var unlock = find(o, "unlockAction");
            if (!unlock) return fail("no unlock action");
            if (!eq(find(unlock, "unlockLink").text, "Unlock", "unlock text")) return;
            if (!eq(String(find(unlock, "unlockMark").color).toLowerCase(), "#06b6d4", "unlock mark colour")) return;
            var ur = Checks.rect(unlock);
            if (!eq(Math.round(ur.x + ur.w), Math.round(o.width - o.margin), "unlock right edge")) return;
            var denied = find(o, "accessDenied");
            if (denied.visible) return fail("access denied shown before a failure");
            field.text = "bad";
            field.input.accepted();
            fake.errorMessage("Authentication failure");
            fake.loginFailed();
            if (!eq(denied.visible, true, "access denied after failure")) return;
            if (!eq(denied.text, "ACCESS DENIED", "access denied text")) return;
            if (find(o, "errorLine")) return fail("second error line appeared");
            if (!eq(String(denied.color).toLowerCase(), "#ef4444", "access denied colour")) return;
            field.text = "g";
            if (denied.visible) return fail("access denied still shown while typing");
            // The Unlock action sends the same login as Enter.
            var before = Checks.count(fake, "login");
            find(unlock, "unlockLink").activated();
            if (!eq(Checks.count(fake, "login"), before + 1, "unlock login calls")) return;
            fake.loginSucceeded();
            // The success plays the reveal; the lock surface showing again brings the resting UI
            // back, which the rest of this test inspects.
            fake.surfaceRevealed();

            settle.start();
        }
    }

    // Let the dial finish turning before comparing its final angle.
    Timer {
        id: settle
        interval: 900
        onTriggered: {
            var o = host.item, dial = find(o, "orbitDial");
            o.now = new Date(2026, 11, 6, 23, 59, 0);
            if (!eq(dial.targetRotation, -354, "target at :59")) return;
            o.now = new Date(2026, 11, 7, 0, 0, 0);
            if (!eq(dial.targetRotation, 0, "target at :00")) return;
            if (!windowShows(o, "00", "minute in the window at :00")) return;
            wrap.start();
        }
    }
    Timer {
        id: wrap
        interval: 900
        onTriggered: {
            var o = host.item, dial = find(o, "orbitDial");
            if (!eq(Math.round(((dial.ringRotation % 360) + 360) % 360), 0, "dial settles at :00")) return;

            // Layout: long names everywhere, three sizes, both clock formats.
            fake.hostName = new Array(80).join("h");
            users.setUsers([new Array(80).join("u")]);
            player.title = new Array(201).join("W");
            player.artist = new Array(201).join("M");
            for (const pair of [[host.item, "1366x768"], [big.item, "3840x2400"], [small.item, "1024x600"]]) {
                var h2 = pair[0];
                h2.playerOverride = player;
                for (const is24 of [true, false]) {
                    h2.clock24h = is24;
                    h2.now = new Date(2026, 11, 6, 23, 55, 0);
                    if (!layoutCheck(h2, pair[1] + (is24 ? " 24h" : " 12h"))) return;
                }
            }

            console.log("PASS: orbit dial, date, sign-in and layout");
            Qt.quit();
        }
    }
}
