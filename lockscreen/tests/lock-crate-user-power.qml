import QtQuick
import QtQuick.Window
import Quickshell
import "harness"
import "harness/SkinChecks.js" as Checks

ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/" + String(Quickshell.env("SKIN")) + "/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false }
    FakeUserModel { id: users }
    Component.onCompleted: users.setUsers(["diego"])
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: host; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: users }
    }

    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }

    Timer {
        interval: 600; running: true
        onTriggered: {
            if (!host.item) return fail("theme did not load");
            if (!Checks.userPower({ fail: root.fail, host: host, fake: fake, users: users })) return;
            console.log("PASS: " + String(Quickshell.env("SKIN")) + " user switch and power row");
            Qt.quit();
        }
    }
}
