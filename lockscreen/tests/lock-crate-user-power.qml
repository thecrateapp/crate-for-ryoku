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

    // SDDM remembering nobody (lastUser ""): one host per model shape. The rows arrive after the
    // skin loaded, as with the shim's ListModel.
    FakeSddm { id: fakeIdx; fingerprintHint: false }
    FakeSddm { id: fakeBad; fingerprintHint: false }
    FakeSddm { id: fakeOne; fingerprintHint: false }
    FakeSddm { id: fakeNone; fingerprintHint: false }
    FakeUserModel { id: usersIdx }
    FakeUserModel { id: usersBad }
    FakeUserModel { id: usersOne }
    FakeUserModel { id: usersNone }
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: hostIdx; anchors.fill: parent; skin: root.skin; sddm: fakeIdx; userModel: usersIdx }
    }
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: hostBad; anchors.fill: parent; skin: root.skin; sddm: fakeBad; userModel: usersBad }
    }
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: hostOne; anchors.fill: parent; skin: root.skin; sddm: fakeOne; userModel: usersOne }
    }
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: hostNone; anchors.fill: parent; skin: root.skin; sddm: fakeNone; userModel: usersNone }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            usersIdx.setUsers(["ana", "diego"], "", 1);
            usersBad.setUsers(["ana", "diego"], "", 7);
            usersOne.setUsers(["solo"], "", 0);
            usersNone.setUsers([], "", 0);
        }
    }

    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }

    Timer {
        interval: 600; running: true
        onTriggered: {
            if (!host.item) return fail("theme did not load");
            if (!Checks.userPower({ fail: root.fail, host: host, fake: fake, users: users })) return;
            if (!Checks.userFallback({ fail: root.fail, cases: [
                    { host: hostIdx, fake: fakeIdx, expect: "diego", label: "empty lastUser, lastIndex 1" },
                    { host: hostBad, fake: fakeBad, expect: "ana", label: "empty lastUser, lastIndex out of range" },
                    { host: hostOne, fake: fakeOne, expect: "solo", label: "empty lastUser, one user" },
                    { host: hostNone, fake: fakeNone, expect: "", label: "no users" }] })) return;
            console.log("PASS: " + String(Quickshell.env("SKIN")) + " user switch and power row");
            Qt.quit();
        }
    }
}
