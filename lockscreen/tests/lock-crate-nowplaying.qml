import QtQuick
import QtQuick.Window
import Quickshell
import "harness"
import "harness/SkinChecks.js" as Checks

ShellRoot {
    id: root
    readonly property string lockRoot: String(Quickshell.env("LOCK_ROOT"))
    readonly property string skin: "file://" + lockRoot + "/" + String(Quickshell.env("SKIN")) + "/Main.qml"

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

    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }

    Timer {
        interval: 600; running: true
        onTriggered: {
            if (!host.item || !sddmHost.item) return fail("theme did not load");
            var t = { fail: root.fail, host: host, sddmHost: sddmHost, liveHost: liveHost, player: player, lockRoot: lockRoot,
                createComponent: function (u) { return Qt.createComponent(u); } };
            if (!Checks.nowPlaying(t)) return;
            console.log("PASS: " + String(Quickshell.env("SKIN")) + " now playing");
            Qt.quit();
        }
    }
}
