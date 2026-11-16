import QtQuick
import "i18n"

// Single-underline password field. Skins never authenticate: this calls sddm.login or, while a
// security key waits for its PIN, sddm.loginKeyPin, and reacts to sddm.loginFailed/loginSucceeded.
FocusScope {
    id: root
    // Design pixels scale per skin instance: the host binds this to its own height / 1200.
    property real uiScale: 1
    objectName: "passwordField"

    property string user: ""
    property int sessionIndex: 0
    property string keyState: ""
    // "idle" | "typing" | "checking" | "error"
    state: "idle"
    property string errorText: ""
    property alias text: input.text
    readonly property alias input: input
    property bool reduceMotion: CratePalette.reduceMotion
    signal submitted()
    // PAM never answered (a security key that timed out, a VT switch that aborted the
    // conversation): the field left "checking" on its own, so a skin stops waiting too.
    signal checkAbandoned()

    // A transient line for AuthHint ("KEY TIMED OUT"); typing or a new attempt clears it.
    property string notice: ""
    // Longest "checking" may last without an answer before the field takes itself back. Longer
    // than the shim's 10 s security-key touch wait, so its keyTimedOut normally comes first.
    property int checkTimeoutMs: 12000

    // Last PAM text, if the host provides one (the Ryoku shim has no such signal yet).
    property string pamMessage: ""

    states: [ State { name: "idle" }, State { name: "typing" }, State { name: "checking" }, State { name: "error" } ]

    implicitWidth: Math.round(CratePalette.s(360, root.uiScale))
    implicitHeight: Math.round(CratePalette.s(44, root.uiScale))

    function clear() {
        input.text = "";
        if (state === "typing") state = "idle";
    }
    // Leaves a security-key PIN prompt for the password (the shim keeps the field on the PIN until then).
    function cancelPin() {
        if (keyState !== "pin" || typeof sddm === "undefined" || !sddm || sddm.usePassword === undefined) return;
        input.text = "";
        sddm.usePassword();
    }
    function focusField() { input.forceActiveFocus(); }
    // Out of "checking" without a PAM answer: nothing typed survives, the field is ready again.
    function abandonCheck(message) {
        checkWatchdog.stop();
        if (state !== "checking") return;
        input.text = "";
        state = "idle";
        notice = message || "";
        input.forceActiveFocus();
        root.checkAbandoned();
    }

    Timer {
        id: checkWatchdog
        objectName: "checkWatchdog"
        interval: root.checkTimeoutMs
        running: root.state === "checking"
        onTriggered: root.abandonCheck("")
    }
    // The key moved on (PIN sent, now waiting for a touch): give the new wait its full time.
    onKeyStateChanged: if (state === "checking") checkWatchdog.restart()

    function submit() {
        if (state === "checking" || input.text === "") return;
        // Never a login for nobody: SDDM with no user to offer has nothing to sign in.
        if (user === "") {
            input.text = "";
            errorText = I18n.tr("noUser");
            state = "error";
            return;
        }
        var value = input.text;
        state = "checking";
        errorText = "";
        notice = "";
        root.submitted();
        if (typeof sddm === "undefined" || !sddm) return;
        if (keyState === "pin") sddm.loginKeyPin(user, value);
        else sddm.login(user, value, sessionIndex);
    }

    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: -Math.round(CratePalette.s(2, root.uiScale)) }
        focus: true
        echoMode: TextInput.Password
        passwordCharacter: "•"
        color: CratePalette.text
        selectionColor: CratePalette.cyan
        selectedTextColor: CratePalette.canvas
        font.family: CratePalette.monoFamily
        font.pixelSize: Math.round(CratePalette.s(22, root.uiScale))
        font.letterSpacing: Math.round(CratePalette.s(22, root.uiScale)) * 0.2
        clip: true
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
        cursorDelegate: Rectangle { width: 2; color: CratePalette.cyan; visible: input.activeFocus }
        Accessible.role: Accessible.EditableText
        Accessible.name: I18n.tr("password")
        Accessible.passwordEdit: true
        onAccepted: root.submit()
        Keys.onEscapePressed: root.cancelPin()
        onTextChanged: {
            if (text !== "") root.notice = "";
            if (root.state === "checking") return;
            if (text !== "") root.state = "typing";
            else if (root.state === "typing") root.state = "idle";
        }
    }

    Rectangle {
        id: underline
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.state === "error" || input.activeFocus ? 2 : 1
        color: root.state === "error" ? CratePalette.danger
             : input.activeFocus || root.state === "checking" ? CratePalette.cyan
             : CratePalette.hairline
    }

    SequentialAnimation {
        id: nudge
        NumberAnimation { target: input; property: "anchors.leftMargin"; to: 8; duration: 50; easing.type: Easing.InOutSine }
        NumberAnimation { target: input; property: "anchors.leftMargin"; to: -8; duration: 70; easing.type: Easing.InOutSine }
        NumberAnimation { target: input; property: "anchors.leftMargin"; to: 0; duration: 50; easing.type: Easing.InOutSine }
    }

    Connections {
        target: typeof sddm !== "undefined" && sddm && sddm.loginFailed !== undefined ? sddm : null
        ignoreUnknownSignals: true
        function onErrorMessage(message) { root.pamMessage = message || ""; }
        function onLoginFailed() {
            input.text = "";
            root.notice = "";
            root.errorText = root.pamMessage !== "" ? root.pamMessage : I18n.tr("wrongPassword");
            root.pamMessage = "";
            root.state = "error";
            input.forceActiveFocus();
            if (!root.reduceMotion) nudge.restart();
        }
        // The touch wait ran out: the shim hands the field back to the password and sends
        // nothing else, so this is the end of the attempt.
        function onKeyTimedOut() {
            if (root.state === "checking") root.abandonCheck(I18n.tr("KEY TIMED OUT"));
            else { root.notice = I18n.tr("KEY TIMED OUT"); input.forceActiveFocus(); }
        }
        function onLoginSucceeded() {
            // The shell can still cancel the unlock without a loginFailed: no password stays behind.
            input.text = "";
            root.notice = "";
            root.errorText = "";
            root.pamMessage = "";
            root.state = "idle";
        }
    }
}
