import QtQuick
import QtQuick.Window
import Quickshell
import "harness"

ShellRoot {
    id: root
    readonly property string lockRoot: String(Quickshell.env("LOCK_ROOT"))
    readonly property string skin: "file://" + lockRoot + "/crate/hero/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false }
    FakeSddm { id: plainSddm; fingerprintHint: undefined }
    FakeUserModel { id: users }
    FakeUserModel { id: users2 }
    FakePlayer { id: player; title: "Blending"; artist: "High Vis"; position: 50; length: 200; playing: true }
    Component.onCompleted: { users.setUsers(["diego"]); users2.setUsers(["diego"]); }

    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: host; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: users }
    }
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: sddmHost; anchors.fill: parent; skin: root.skin; sddm: plainSddm; userModel: users2 }
    }

    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: liveHost; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: users }
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

    Timer {
        interval: 600; running: true
        onTriggered: {
            if (!host.item || !sddmHost.item) return fail("theme did not load");
            var hero = host.item;
            var np = find(hero, "nowPlaying");
            if (!np) return fail("no nowPlaying block");
            var field = find(hero, "passwordField");

            // No player yet: hidden.
            if (!eq(np.visible, false, "visible without player")) return;

            // Playing: visible with both texts and a proportional progress width.
            hero.playerOverride = player;
            if (!eq(np.visible, true, "visible while playing")) return;
            if (!eq(find(np, "nowPlayingTitle").text, "Blending", "title")) return;
            if (!eq(find(np, "nowPlayingArtist").text, "High Vis", "artist")) return;
            var track = find(np, "nowPlayingTrack");
            var fill = find(np, "nowPlayingProgress");
            if (!track || !fill) return fail("no progress bar");
            if (!eq(Math.round(fill.width * 1000 / track.width), 250, "progress 50/200")) return;
            player.position = 150;
            if (!eq(Math.round(fill.width * 1000 / track.width), 750, "progress 150/200")) return;
            player.length = 0;
            if (!eq(fill.width, 0, "zero length progress")) return;
            player.length = 200;

            // Paused: hidden.
            player.playing = false;
            if (!eq(np.visible, false, "visible while paused")) return;
            player.playing = true;

            // Long title: one line, elided, clear of the password field.
            player.title = new Array(201).join("W");
            var title = find(np, "nowPlayingTitle");
            if (!title.truncated) return fail("200 char title not elided");
            if (!eq(title.lineCount, 1, "title lines")) return;
            if (title.paintedWidth > title.width + 1) return fail("title wider than its box");
            player.artist = new Array(201).join("M");
            if (!find(np, "nowPlayingArtist").truncated) return fail("long artist not elided");
            if (intersects(rect(np), rect(field))) return fail("now playing overlaps the password field");
            if (rect(np).x + rect(np).w > hero.width) return fail("now playing leaves the screen");
            player.title = "Blending";
            player.artist = "High Vis";

            // Player goes away mid-test: hidden, and it returns when it comes back.
            hero.playerOverride = null;
            if (!eq(np.visible, false, "visible with null player")) return;
            hero.playerOverride = player;
            if (!eq(np.visible, true, "visible again")) return;

            // theme.conf showNowPlaying = "false" hides it.
            host.config = ({ showNowPlaying: "false" });
            if (!eq(np.visible, false, "visible with showNowPlaying=false")) return;
            host.config = ({ showNowPlaying: "true" });
            if (!eq(np.visible, true, "visible with showNowPlaying=true")) return;
            host.config = ({});

            // Compact: one mono line, no cover, no progress.
            var comp = Qt.createComponent("file://" + lockRoot + "/crate/common/NowPlaying.qml");
            if (comp.status !== Component.Ready) return fail("NowPlaying.qml: " + comp.errorString());
            var c = comp.createObject(hero, { player: player, compact: true, width: 400 });
            if (!c) return fail("compact create");
            if (!eq(c.visible, true, "compact visible")) return;
            if (find(c, "nowPlayingProgress").visible || find(c, "nowPlayingCover").visible) return fail("compact has cover or progress");
            var line = find(c, "nowPlayingLine");
            if (!line) return fail("compact has no line");
            if (!eq(line.text, "NOW PLAYING · High Vis — Blending", "compact text")) return;
            c.destroy();

            // SDDM mode: the Mpris loader is inactive and the block stays hidden.
            var sddmHero = sddmHost.item;
            if (!eq(sddmHero.sessionLock, false, "sddm sessionLock")) return;
            var loader = find(sddmHero, "mprisLoader");
            if (!loader) return fail("no mprisLoader");
            if (!eq(loader.status, Loader.Null, "sddm loader status")) return;
            if (!eq(find(sddmHero, "nowPlaying").visible, false, "sddm block visible")) return;

            // Session lock without an override: the Mpris loader runs and, whether a Crate player is on the bus depends on the machine, so only the wiring is checked.
            var live = find(liveHost.item, "mprisLoader");
            if (!eq(live.status, Loader.Ready, "session loader status")) return;
            var livePlayer = live.item.player;
            if (!eq(find(liveHost.item, "nowPlaying").visible, !!livePlayer && livePlayer.playing, "live block follows the bus")) return;

            console.log("PASS: now playing");
            Qt.quit();
        }
    }
}
