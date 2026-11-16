import QtQuick
import "../common"
import "../common/i18n"

Item {
    id: root

    // Set by qylock's loader when running as a session lock.
    property bool clock24h: true
    property var clockLocale: Qt.locale()
    // The session lock shim exposes sddm.fingerprintHint; the real SDDM greeter does not.
    readonly property bool sessionLock: typeof sddm !== "undefined" && sddm.fingerprintHint !== undefined
    // theme.conf values. qylock and SDDM provide `config` as a context property; a root property
    // named `config` would shadow it, so the skin reads it into themeConfig instead.
    readonly property var themeConfig: typeof config !== "undefined" && config ? config : ({})
    property date now: new Date()
    readonly property var users: typeof userModel !== "undefined" ? userModel : null
    // Login identity: the switcher's current user.
    readonly property string user: userSwitch.currentUser !== "" ? userSwitch.currentUser : "user"
    readonly property int sessionIndex: typeof sessionModel !== "undefined" && sessionModel && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    readonly property bool fontsReady: CratePalette.fontsReady
    readonly property bool reduceMotion: CratePalette.reduceMotion
    readonly property bool tokensLinked: CratePalette.tokensLinked
    readonly property string displayFamily: CratePalette.displayFamily

    // Tokens exist only under the Ryoku shell; SDDM never touches them.
    Component.onCompleted: {
        if (sessionLock) CratePalette.linkTokens();
        // The shim drops key PIN requests unless the skin says it draws them (keyState in AuthHint).
        if (sessionLock) sddm.keyPrompts = true;
        passwordField.focusField();
    }

    anchors.fill: parent
    implicitWidth: 1366
    implicitHeight: 768

    Background {
        anchors.fill: parent
        kind: root.themeConfig.background === "sheen" ? "sheen" : "groove"
    }

    Column {
        id: authColumn
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: Math.round(CratePalette.s(96)); bottomMargin: Math.round(CratePalette.s(96)) }
        width: Math.min(Math.round(CratePalette.s(360)), parent.width - Math.round(CratePalette.s(192)))
        spacing: Math.round(CratePalette.s(10))

        Text {
            width: parent.width
            text: I18n.tr("password").toUpperCase()
            color: CratePalette.secondary
            elide: Text.ElideRight
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12))
            font.letterSpacing: Math.round(CratePalette.s(12)) * 0.14
        }
        PasswordField {
            id: passwordField
            width: parent.width
            focus: true
            user: root.user
            sessionIndex: root.sessionIndex
            keyState: typeof sddm !== "undefined" && sddm && sddm.keyState !== undefined ? String(sddm.keyState) : ""
        }
        Row {
            width: parent.width
            spacing: Math.round(CratePalette.s(12))
            Text {
                id: userLabel
                text: I18n.tr("user").toUpperCase() + " \u00b7"
                color: CratePalette.faint
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(12))
                font.letterSpacing: Math.round(CratePalette.s(12)) * 0.14
            }
            UserSwitch {
                id: userSwitch
                width: parent.width - userLabel.width - parent.spacing
                model: root.users
                onActivated: passwordField.focusField()
            }
        }
        ErrorLine { width: parent.width; shown: passwordField.state === "error"; text: passwordField.errorText }
        AuthHint {
            width: parent.width
            authState: passwordField.state
            keyState: passwordField.keyState
            fingerprintState: root.sessionLock && sddm.fingerprintState !== undefined ? String(sddm.fingerprintState) : ""
        }
    }

    PowerRow {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: Math.round(CratePalette.s(96)); bottomMargin: Math.round(CratePalette.s(96)) }
        onActivated: passwordField.focusField()
    }
}
