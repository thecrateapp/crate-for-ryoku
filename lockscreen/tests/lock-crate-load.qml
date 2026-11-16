import QtQuick
import Quickshell
import "harness"

ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/crate/hero/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false }

    // SDDM_ONLY runs without the stub Ryoku module on the import path: only the SDDM skins load.
    readonly property bool sddmOnly: String(Quickshell.env("SDDM_ONLY")) === "1"
    TestHost { id: lockHost; skin: root.sddmOnly ? "" : root.skin; sddm: fake }
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
            if ((!root.sddmOnly && !lockHost.item) || !sddmHost.item || !sheenHost.item) return fail("theme did not load");
            if (root.sddmOnly) {
                if (sddmHost.item.sessionLock !== false || sddmHost.item.tokensLinked) return fail("SDDM mode touched Ryoku tokens");
                if (!sddmHost.item.fontsReady) return fail("display font not loaded");
                var sbg = find(sheenHost.item, "background");
                if (!sbg || !String(sbg.source).endsWith("sheen.webp")) return fail("config.background=sheen did not pick sheen.webp");
                console.log("PASS: hero loads in SDDM without Ryoku modules");
                Qt.quit();
                return;
            }
            if (lockHost.item.sessionLock !== true) return fail("session lock not detected");
            if (sddmHost.item.sessionLock !== false) return fail("SDDM mode detected as session lock");
            if (!lockHost.item.tokensLinked) return fail("session lock did not link Ryoku tokens");
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
