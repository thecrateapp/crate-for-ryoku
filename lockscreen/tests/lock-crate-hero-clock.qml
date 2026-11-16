import QtQuick
import QtQuick.Window
import Quickshell
import "harness"

ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/crate/hero/Main.qml"

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

    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) {
            var r = find(item.children[i], name);
            if (r) return r;
        }
        return null;
    }
    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }
    function eq(a, b, what) { if (String(a) !== String(b)) { fail(what + ": expected " + b + ", got " + a); return false; } return true; }
    function rect(item) {
        var p = item.mapToItem(null, 0, 0);
        return { x: p.x, y: p.y, w: item.width, h: item.height };
    }
    function intersects(a, b) {
        return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
    }
    function within(r, hero) { return r.x >= 0 && r.y >= 0 && r.x + r.w <= hero.width && r.y + r.h <= hero.height; }

    // Wide enough to fill the layout: long names in every slot.
    function layoutCheck(hero, label) {
        var names = ["clockBlock", "nowPlaying", "authColumn", "headerRow", "powerRow"];
        var r = {};
        for (var i = 0; i < names.length; i++) {
            var it = find(hero, names[i]);
            if (!it) return fail(label + ": no " + names[i]);
            r[names[i]] = rect(it);
            if (!within(r[names[i]], hero)) return fail(label + ": " + names[i] + " leaves the screen");
        }
        // Scale is per skin instance (its own height / 1200) and the clock fits the room it has,
        // measured with the real Bricolage font.
        if (!hero.fontsReady) return fail(label + ": fonts not ready");
        if (Math.abs(hero.uiScale - hero.height / 1200) > 1e-9) return fail(label + ": uiScale is not height / 1200");
        var clk = find(hero, "clock");
        if (Math.abs(clk.fitPx - Math.round(300 * hero.uiScale)) > 1) return fail(label + ": clock size " + clk.fitPx + " is not 300 * uiScale");
        var cb = find(hero, "clockBlock");
        if (cb.width > cb.maxWidth) return fail(label + ": clock block " + cb.width + " wider than its room " + cb.maxWidth);
        var np0 = find(hero, "nowPlaying");
        if (np0.width <= 0 || Math.abs(np0.width - Math.round(420 * hero.uiScale)) > 1) return fail(label + ": now playing width " + np0.width);
        var pairs = [["clockBlock", "nowPlaying"], ["clockBlock", "authColumn"], ["nowPlaying", "authColumn"],
                     ["headerRow", "powerRow"], ["headerRow", "clockBlock"], ["powerRow", "authColumn"]];
        for (var j = 0; j < pairs.length; j++)
            if (intersects(r[pairs[j][0]], r[pairs[j][1]])) return fail(label + ": " + pairs[j][0] + " overlaps " + pairs[j][1]);
        return true;
    }

    Timer {
        interval: 700; running: true
        onTriggered: {
            if (!host.item || !big.item || !small.item) return fail("theme did not load");
            var hero = host.item;
            for (const h of [host.item, big.item, small.item]) {
                h.liveClock = false;
                h.clockLocale = Qt.locale("en_US");
                h.now = new Date(2026, 11, 6, 23, 5, 0);
            }
            var clock = find(hero, "clock");
            if (!clock) return fail("no clock");

            // 24 h.
            hero.clock24h = true;
            if (!eq(clock.text, "23:05", "24 h clock")) return;
            if (find(hero, "clockAmPm").visible) return fail("AM/PM shown in 24 h");

            // 12 h.
            hero.clock24h = false;
            if (!eq(clock.text, "11:05", "12 h clock")) return;
            var ap = find(hero, "clockAmPm");
            if (!eq(ap.text, "PM", "AM/PM") || !ap.visible) return;
            hero.clock24h = true;

            // Date line: weekday cyan-hi, rest secondary, mono.
            var wd = find(hero, "dateWeekday"), rest = find(hero, "dateRest");
            if (!eq(wd.text, "SUNDAY", "weekday")) return;
            if (!eq(rest.text, "06 DEC 2026", "date rest")) return;
            if (!eq(String(wd.color).toLowerCase(), "#67e8f9", "weekday colour")) return;
            if (String(wd.font.family) === "" || String(wd.font.family) !== String(rest.font.family)) return fail("date is not one mono family");

            // Header.
            var locked = find(hero, "headerLocked"), hostText = find(hero, "headerHost");
            if (!eq(locked.text, "LOCKED", "header")) return;
            if (!eq(hostText.text, "crate-host", "header host")) return;

            settle.start();
        }
    }
    // Let the slides from the format switches finish before checking which digit slides.
    Timer {
        id: settle
        interval: 400
        onTriggered: {
            var hero = host.item, clock = find(hero, "clock");
            // A changed digit slides for 120 ms; the others stay.
            var s4 = find(hero, "clockSlot4"), s0 = find(hero, "clockSlot0");
            if (!eq(s4.slideDuration, 120, "slide duration")) return;
            hero.now = new Date(2026, 11, 6, 23, 6, 0);
            if (!eq(clock.text, "23:06", "clock after a minute")) return;
            if (!s4.sliding) return fail("changed digit did not slide");
            if (s0.sliding) return fail("unchanged digit slid");

            // User block.
            var link = find(hero, "userSwitchLink");
            if (!eq(link.label.font.weight, Font.Bold, "user name weight")) return;
            if (!eq(find(hero, "userAddress").text, "diego@crate-host", "user@host")) return;
            if (find(hero, "authColumn").visible !== true) return fail("auth column hidden");
            if (!eq(find(hero, "passwordLabel").text, "PASSWORD", "password label")) return;

            // Layout: long names everywhere, both sizes, 24 h and 12 h.
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

            console.log("PASS: hero clock, date and header");
            Qt.quit();
        }
    }
}
