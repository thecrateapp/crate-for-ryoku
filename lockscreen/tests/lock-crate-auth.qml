import QtQuick
import QtQuick.Window
import Quickshell
import "harness"

ShellRoot {
    id: root
    readonly property string skin: "file://" + String(Quickshell.env("LOCK_ROOT")) + "/crate/hero/Main.qml"

    FakeSddm { id: fake; fingerprintHint: false }
    // Focus only exists inside a window. Offscreen platform, no session lock.
    Window {
        visible: true; width: 1366; height: 768
        TestHost { id: host; anchors.fill: parent; skin: root.skin; sddm: fake; userModel: ({ lastUser: "diego", lastIndex: 0 }) }
    }

    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) {
            var r = find(item.children[i], name);
            if (r) return r;
        }
        return null;
    }
    // The shell root dir is tests/, so the catalogue is imported by URL at run time.
    readonly property var i18n: Qt.createQmlObject(
        'import QtQuick\nimport "file://' + String(Quickshell.env("LOCK_ROOT")) + '/crate/common/i18n"\n'
        + 'QtObject { function tr(k) { return I18n.tr(k) } }', root, "i18n")
    function fail(msg) { console.error("FAIL: " + msg); Qt.quit(); }
    function eq(a, b, what) { if (String(a) !== String(b)) { fail(what + ": expected " + b + ", got " + a); return false; } return true; }
    function count(name) { return fake.calls.filter(c => c[0] === name).length; }

    Timer {
        interval: 600; running: true
        onTriggered: {
            if (!host.item) return fail("theme did not load");
            var f = find(host.item, "passwordField");
            var err = find(host.item, "errorLine");
            var hint = find(host.item, "authHint");
            if (!f) return fail("no passwordField");
            if (!err) return fail("no errorLine");
            if (!hint) return fail("no authHint");
            if (!f.activeFocus) return fail("password field is not focused on load");
            if (fake.keyPrompts !== true) return fail("skin did not set sddm.keyPrompts in session lock");
            if (!eq(f.state, "idle", "initial state")) return;

            // Empty Enter calls nothing.
            f.input.accepted();
            if (!eq(count("login"), 0, "empty Enter login calls")) return;

            // Typing + Enter.
            f.text = "hunter2";
            if (!eq(f.state, "typing", "state while typing")) return;
            f.input.accepted();
            if (!eq(count("login"), 1, "login calls")) return;
            var c = fake.calls[0];
            if (!eq(JSON.stringify(c), JSON.stringify(["login", "diego", "hunter2", 0]), "login args")) return;
            if (!eq(f.state, "checking", "state after Enter")) return;
            if (f.input.enabled) return fail("field still enabled while checking");

            // Wrong password.
            fake.errorMessage("Authentication failure");
            fake.loginFailed();
            if (!eq(f.state, "error", "state after loginFailed")) return;
            if (!eq(f.text, "", "field text after loginFailed")) return;
            if (!err.visible) return fail("error line hidden after failure");
            if (!eq(String(err.color).toLowerCase(), "#ef4444", "error colour")) return;
            if (!eq(err.text, "Authentication failure", "PAM text")) return;
            if (!f.activeFocus) return fail("field lost focus after failure");

            // Review focus 1: typing clears the red state.
            f.text = "h";
            if (!eq(f.state, "typing", "state after typing again")) return;
            if (err.visible) return fail("error line still visible while typing");

            // Success leaves no error.
            f.input.accepted();
            fake.loginSucceeded();
            if (err.visible) return fail("error visible after success");

            // Failure without a PAM message falls back to the English line.
            fake.errorMessage("");
            f.text = "x";
            f.input.accepted();
            fake.loginFailed();
            if (!eq(err.text, root.i18n.tr("wrongPassword"), "fallback text")) return;

            // Security key PIN.
            fake.requestKeyState("pin");
            if (!eq(fake.keyState, "pin", "keyState with keyPrompts set")) return;
            f.text = "1234";
            var logins = count("login");
            f.input.accepted();
            if (!eq(count("login"), logins, "login calls in PIN mode")) return;
            if (!eq(count("loginKeyPin"), 1, "loginKeyPin calls")) return;
            if (!eq(JSON.stringify(fake.calls[fake.calls.length - 1]), JSON.stringify(["loginKeyPin", "diego", "1234"]), "loginKeyPin args")) return;
            if (!eq(hint.text, root.i18n.tr("SECURITY KEY PIN") + " \u00b7 " + root.i18n.tr("ESC TO USE PASSWORD"), "PIN hint text")) return;
            fake.loginFailed();

            // Esc leaves the PIN prompt for the password; Enter then calls login.
            f.text = "";
            f.cancelPin();
            if (!eq(count("usePassword"), 1, "usePassword calls")) return;
            if (!eq(fake.keyState, "off", "keyState after usePassword")) return;
            f.cancelPin();
            if (!eq(count("usePassword"), 1, "Esc outside PIN mode")) return;
            f.text = "pw";
            logins = count("login");
            var pins = count("loginKeyPin");
            f.input.accepted();
            if (!eq(count("login"), logins + 1, "login after leaving PIN")) return;
            if (!eq(count("loginKeyPin"), pins, "loginKeyPin after leaving PIN")) return;
            fake.loginFailed();

            // Fingerprint hint.
            fake.fingerprintState = "scanning";
            if (!eq(hint.text, root.i18n.tr("or touch the reader"), "scanning hint")) return;
            if (!eq(String(hint.color).toLowerCase(), "#67e8f9", "scanning colour")) return;
            fake.fingerprintState = "fail";
            if (!eq(String(hint.color).toLowerCase(), "#ef4444", "fail colour")) return;
            fake.fingerprintState = "";
            if (hint.visible) return fail("hint visible with nothing to say");

            console.log("PASS: password field, hints and auth states");
            Qt.quit();
        }
    }
}
