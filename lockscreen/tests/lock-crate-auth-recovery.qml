import QtQuick
import QtQuick.Window
import Quickshell
import "harness"
import "harness/SkinChecks.js" as Checks

// A login PAM never answers (a VT switch aborted the conversation): the field must not stay in
// "checking". Shared by every skin through SkinChecks.recovery*.
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
    readonly property var t: ({ fail: root.fail, host: host, fake: fake })
    property int step: 0
    Timer {
        id: runner
        interval: 600; running: true
        onTriggered: {
            if (!host.item) return fail("theme did not load");
            var steps = [Checks.recoveryArm, Checks.recoveryFired, Checks.recoveryAnswered];
            if (!steps[root.step++](root.t)) return;
            if (root.step < steps.length) { runner.interval = 600; runner.start(); return; }
            console.log("PASS: " + String(Quickshell.env("SKIN")) + " leaves checking when PAM never answers");
            Qt.quit();
        }
    }
}
