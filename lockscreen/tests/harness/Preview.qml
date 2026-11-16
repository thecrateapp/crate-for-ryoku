import QtQuick
import QtQuick.Window
import Quickshell

// Preview shell: hosts one Crate skin in a plain window (never a session lock) and drives the
// fakes into a named state. Configured by environment (see preview.sh): PV_SKIN, PV_STATE,
// PV_SIZE (WxH), PV_SHOT (output PNG; unset = windowed), PV_LOCK_ROOT.
ShellRoot {
    id: root
    readonly property string lockRoot: String(Quickshell.env("PV_LOCK_ROOT"))
    readonly property string skinName: String(Quickshell.env("PV_SKIN"))
    readonly property string state: String(Quickshell.env("PV_STATE"))
    readonly property string shotPath: String(Quickshell.env("PV_SHOT") || "")
    readonly property var dims: String(Quickshell.env("PV_SIZE") || "1920x1200").split("x").map(Number)
    readonly property bool sddmMode: state === "sddm"
    property bool applied: false
    property bool shotTaken: false

    FakeSddm {
        id: fake
        hostName: "innsmouth"
        fingerprintHint: root.sddmMode ? undefined : ""
    }
    FakeUserModel { id: users; Component.onCompleted: setUsers(["diego"]) }
    FakePlayer {
        id: player
        title: "Blending"; artist: "High Vis"
        artUrl: Qt.resolvedUrl("cover.png")
        position: 74; length: 212
    }

    Window {
        id: win
        visible: true
        width: root.dims[0]; height: root.dims[1]
        color: "#0a0a0f"
        title: "Crate lock preview: " + root.skinName
        onClosing: Qt.quit()
        TestHost {
            id: host
            anchors.fill: parent
            skin: "file://" + root.lockRoot + "/" + root.skinName + "/Main.qml"
            sddm: fake
            userModel: users
            config: ({ showNowPlaying: "true", background: "groove" })
        }
    }

    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) {
            var r = find(item.children[i], name);
            if (r) return r;
        }
        return null;
    }
    function bad(msg) { console.error("PREVIEW ERROR: " + msg); Qt.exit(1); }

    function apply() {
        var it = host.item, f = find(it, "passwordField");
        if (!it || !f) return false;
        it.clockLocale = Qt.locale("en_US");
        it.liveClock = false;
        it.now = new Date(2026, 10, 16, 16, 42, 7);
        it.playerOverride = (root.state === "no-music" || root.sddmMode) ? null : player;
        switch (root.state) {
        case "typing": f.text = "hunter2hunter"; break;
        case "checking": f.text = "hunter2hunter"; f.submit(); break;
        // PAM still working: orbit's rings wind up (the shot waits for a mid-windup frame).
        case "windup": f.text = "hunter2hunter"; f.submit(); break;
        case "error": f.text = "hunter2"; f.submit(); fake.loginFailed(); break;
        case "fp-scanning": case "fp-success": case "fp-fail":
            fake.fingerprintReady = true;
            fake.fingerprintHint = "Place your finger on the reader";
            fake.fingerprintState = root.state.substring(3); break;
        case "key-pin": fake.requestKeyState("pin"); break;
        case "key-touch": fake.requestKeyState("touch"); break;
        }
        return true;
    }

    // Ready: skin loaded, fonts loaded, background image decoded, state applied for a few frames.
    function ready() {
        var it = host.item;
        if (!it || !it.fontsReady) return false;
        var dial = find(it, "orbitDial");
        // Orbit winding up (checking, windup): wait for a mid-windup frame, streaks out.
        if (dial && it.motionState === "windup") {
            if (it.windupProgress < 0.55) return false;
        // Otherwise a dial still turning is not a faithful frame: wait until it sits on its target.
        } else if (dial && (it.motionState !== "idle" || Math.abs(dial.ringRotation - dial.targetRotation) > 0.01)) return false;
        return imagesReady(it);
    }
    // Every Image in the tree (wallpaper, cover) has finished loading.
    function imagesReady(item) {
        if (item.status !== undefined && item.progress !== undefined && item.fillMode !== undefined && String(item.source) !== "" && item.status !== Image.Ready) return false;
        for (var i = 0; i < item.children.length; i++) if (!imagesReady(item.children[i])) return false;
        return true;
    }

    Timer {
        id: poll
        interval: 50; repeat: true; running: true
        property int settle: 0
        onTriggered: {
            if (!root.applied) { root.applied = root.apply(); return; }
            if (root.shotPath === "" || root.shotTaken) return;
            if (!root.ready()) { settle = 0; return; }
            if (++settle < 4) return;   // let the state's bindings and animations land
            root.shotTaken = true;
            host.grabToImage(function (res) {
                if (!res.saveToFile(root.shotPath)) return root.bad("could not save " + root.shotPath);
                console.log("shot: " + root.shotPath);
                Qt.quit();
            });
        }
    }
    Timer {
        interval: 20000; running: root.shotPath !== ""
        onTriggered: root.bad("timed out waiting for the skin to be ready")
    }
}
