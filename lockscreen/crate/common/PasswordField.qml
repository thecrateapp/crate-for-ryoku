import QtQuick
import "i18n"

// Single-underline password field. Skins never authenticate: this calls sddm.login or, while a
// security key waits for its PIN, sddm.loginKeyPin, and reacts to sddm.loginFailed/loginSucceeded.
FocusScope {
    id: root
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

    // Last PAM text, if the host provides one (the Ryoku shim has no such signal yet).
    property string pamMessage: ""

    states: [ State { name: "idle" }, State { name: "typing" }, State { name: "checking" }, State { name: "error" } ]

    implicitWidth: Math.round(CratePalette.s(360))
    implicitHeight: Math.round(CratePalette.s(44))

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

    function submit() {
        if (state === "checking" || input.text === "") return;
        var value = input.text;
        state = "checking";
        errorText = "";
        root.submitted();
        if (typeof sddm === "undefined" || !sddm) return;
        if (keyState === "pin") sddm.loginKeyPin(user, value);
        else sddm.login(user, value, sessionIndex);
    }

    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: -Math.round(CratePalette.s(2)) }
        focus: true
        echoMode: TextInput.Password
        passwordCharacter: "•"
        enabled: root.state !== "checking"
        color: CratePalette.text
        selectionColor: CratePalette.cyan
        selectedTextColor: CratePalette.canvas
        font.family: CratePalette.monoFamily
        font.pixelSize: Math.round(CratePalette.s(22))
        font.letterSpacing: Math.round(CratePalette.s(22)) * 0.2
        clip: true
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
        cursorDelegate: Rectangle { width: 2; color: CratePalette.cyan; visible: input.activeFocus }
        Accessible.role: Accessible.EditableText
        Accessible.name: I18n.tr("password")
        Accessible.passwordEdit: true
        onAccepted: root.submit()
        Keys.onEscapePressed: root.cancelPin()
        onTextChanged: {
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
            root.errorText = root.pamMessage !== "" ? root.pamMessage : I18n.tr("wrongPassword");
            root.pamMessage = "";
            root.state = "error";
            input.forceActiveFocus();
            if (!root.reduceMotion) nudge.restart();
        }
        function onLoginSucceeded() {
            root.errorText = "";
            root.pamMessage = "";
            root.state = "idle";
        }
    }
}
