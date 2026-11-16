import QtQuick
import QtQuick.Window
import Quickshell
import "harness"

ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/crate/hero/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false }
    FakeUserModel { id: users }
    Component.onCompleted: users.setUsers(["diego"])
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: host; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: users }
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
    function count(name) { return fake.calls.filter(c => c[0] === name).length; }

    Timer {
        interval: 600; running: true
        onTriggered: {
            if (!host.item) return fail("theme did not load");
            var f = find(host.item, "passwordField");
            var sw = find(host.item, "userSwitch");
            var link = find(host.item, "userSwitchLink");
            if (!f || !sw || !link) return fail("missing field, userSwitch or its link");

            // One user: name shown, not clickable.
            if (!eq(link.text, "diego", "one-user name")) return;
            var area = find(link, "hoverArea");
            if (area.enabled) return fail("single user name is clickable");
            if (!eq(host.item.user, "diego", "root user")) return;

            // Two users: click cycles, Enter logs in as the new one.
            users.setUsers(["diego", "ana"]);
            users.lastUser = "diego";
            if (!eq(sw.userCount, 2, "user count")) return;
            if (!area.enabled) return fail("two users but name not clickable");
            f.forceActiveFocus();
            area.clicked(null);
            if (!eq(sw.currentUser, "ana", "after first click")) return;
            if (!f.activeFocus) return fail("field lost focus after user click");
            f.text = "pw";
            f.input.accepted();
            if (!eq(JSON.stringify(fake.calls[fake.calls.length - 1]), JSON.stringify(["login", "ana", "pw", 0]), "login as new user")) return;
            fake.loginFailed();
            area.clicked(null);
            if (!eq(sw.currentUser, "diego", "cycle wraps")) return;

            // Power links: one call each, field focused afterwards.
            var names = [["powerSuspend", "suspend"], ["powerReboot", "reboot"], ["powerShutdown", "powerOff"]];
            for (var i = 0; i < names.length; i++) {
                var l = find(host.item, names[i][0]);
                if (!l) return fail("no " + names[i][0]);
                f.input.focus = false;
                find(l, "hoverArea").clicked(null);
                if (!eq(count(names[i][1]), 1, names[i][1] + " calls")) return;
                if (!f.activeFocus) return fail("field lost focus after " + names[i][0]);
                var ul = find(l, "underline");
                if (!eq(ul.height, 1, "underline height")) return;
                if (!eq(String(ul.color).toLowerCase(), "#67e8f9", "underline colour")) return;
            }
            if (!eq(find(find(host.item, "powerSuspend"), "underline").transform[0].xScale, 0, "underline idle scale")) return;

            console.log("PASS: user switch and power row");
            Qt.quit();
        }
    }
}
