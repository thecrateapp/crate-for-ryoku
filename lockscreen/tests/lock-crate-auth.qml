import QtQuick
import QtQuick.Window
import Quickshell
import "harness"
import "harness/SkinChecks.js" as Checks

ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/" + String(Quickshell.env("SKIN")) + "/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false }
    // Focus only exists inside a window. Offscreen platform, no session lock.
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: host; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: ({ lastUser: "diego", lastIndex: 0 }) }
    }

    // The shell root dir is tests/, so the catalogue is imported by URL at run time.
    readonly property var i18n: Qt.createQmlObject(
        'import QtQuick\nimport "file://' + String(Quickshell.env("LOCK_ROOT")) + '/crate/common/i18n"\n'
        + 'QtObject { function tr(k) { return I18n.tr(k) } }', root, "i18n")
    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }

    Timer {
        interval: 600; running: true
        onTriggered: {
            if (!host.item) return fail("theme did not load");
            var t = { deniedOnly: String(Quickshell.env("SKIN")) === "crate/orbit", fail: root.fail, host: host, fake: fake, i18n: root.i18n };
            if (!Checks.auth(t)) return;
            console.log("PASS: " + String(Quickshell.env("SKIN")) + " password field, hints and auth states");
            Qt.quit();
        }
    }
}
