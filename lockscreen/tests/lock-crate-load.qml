import QtQuick
import Quickshell
import "harness"

ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/crate/hero/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false }

    TestHost { id: lockHost; skin: root.skin; sddm: fake }
    TestHost { id: sddmHost; skin: root.skin; sddm: ({}) }
    TestHost { id: sheenHost; skin: root.skin; sddm: ({}); config: ({ background: "sheen" }) }

    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) {
            var r = find(item.children[i], name);
            if (r) return r;
        }
        return null;
    }
    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }

    Timer {
        interval: 600; running: true
        onTriggered: {
            if (!lockHost.item || !sddmHost.item || !sheenHost.item) return fail("theme did not load");
            if (lockHost.item.sessionLock !== true) return fail("session lock not detected");
            if (sddmHost.item.sessionLock !== false) return fail("SDDM mode detected as session lock");
            for (const h of [lockHost, sddmHost]) {
                if (!h.item.fontsReady || h.item.displayFamily === "") return fail("display font not loaded");
            }
            var bg = find(lockHost.item, "background");
            if (!bg || !String(bg.source).endsWith("groove.webp")) return fail("default background is not groove.webp");
            var sb = find(sheenHost.item, "background");
            if (!sb || !String(sb.source).endsWith("sheen.webp")) return fail("config.background=sheen did not pick sheen.webp");
            console.log("PASS: hero loads in lock and SDDM");
            Qt.quit();
        }
    }
}
