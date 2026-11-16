import QtQuick
import Quickshell
import "harness"

ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/" + String(Quickshell.env("SKIN")) + "/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false }

    // SDDM_ONLY runs without the stub Ryoku module on the import path: only the SDDM skins load.
    readonly property bool sddmOnly: String(Quickshell.env("SDDM_ONLY")) === "1"
    // NO_TOKENS runs a session lock with no Ryoku module: tokens must stay unlinked, constants apply.
    readonly property bool noTokens: String(Quickshell.env("NO_TOKENS")) === "1"
    TestHost { id: lockHost; skin: root.sddmOnly ? "" : root.skin; sddm: fake }
    // Real SDDM has no fingerprintHint; keyPrompts is only present so the test can see it untouched.
    QtObject { id: sddmObj; property bool keyPrompts: false }
    TestHost { id: sddmHost; skin: root.skin; sddm: sddmObj }
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
            if (root.noTokens) {
                if (!lockHost.item || lockHost.item.sessionLock !== true) return fail("session lock not detected without Ryoku");
                if (lockHost.item.tokensLinked !== false || lockHost.item.reduceMotion !== false) return fail("tokens linked without a Ryoku module");
                if (!lockHost.item.fontsReady) return fail("display font not loaded");
                console.log("PASS: session lock falls back when Ryoku tokens are unavailable");
                Qt.quit();
                return;
            }
            if ((!root.sddmOnly && !lockHost.item) || !sddmHost.item || !sheenHost.item) return fail("theme did not load");
            if (root.sddmOnly) {
                if (sddmHost.item.sessionLock !== false || sddmHost.item.tokensLinked) return fail("SDDM mode touched Ryoku tokens");
                if (sddmObj.keyPrompts !== false) return fail("keyPrompts changed outside session lock");
                if (!sddmHost.item.fontsReady) return fail("display font not loaded");
                var sbg = find(sheenHost.item, "background");
                if (!sbg || !String(sbg.source).endsWith("sheen.webp")) return fail("config.background=sheen did not pick sheen.webp");
                console.log("PASS: " + String(Quickshell.env("SKIN")) + " loads in SDDM and never links Ryoku tokens");
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
            console.log("PASS: " + String(Quickshell.env("SKIN")) + " loads in lock and SDDM");
            Qt.quit();
        }
    }
}
