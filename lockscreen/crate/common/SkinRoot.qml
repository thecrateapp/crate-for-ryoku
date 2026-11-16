import QtQuick
import "i18n"

// Root shared by every Crate skin: the SDDM / session-lock seam (detection, theme.conf, key
// prompts, tokens, clock, now-playing source, login identity) so a fix to it lands once. A skin's
// Main.qml is `SkinRoot { id: root ... layout ... }`. This file never imports the Mpris module:
// NowPlayingMpris.qml is loaded by file from a Loader that is active only in the session lock.
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
    // Production ticks `now` once a second; tests pin it.
    property bool liveClock: true
    readonly property string hostName: typeof sddm !== "undefined" && sddm && sddm.hostName ? String(sddm.hostName) : ""
    readonly property int margin: Math.round(CratePalette.s(96, root.uiScale))
    Timer {
        interval: 1000; repeat: true; running: root.liveClock
        onTriggered: root.now = new Date()
    }
    // "h" only means a 12 hour clock when the format also has AP; the marker is cut back out of the digits.
    readonly property string marker: root.clockLocale.toString(root.now, "AP")
    readonly property string hourDigits: root.clock24h ? root.clockLocale.toString(root.now, "HH")
        : root.clockLocale.toString(root.now, "h AP").replace(marker, "").trim()
    // theme.conf `showNowPlaying` is the string "true"/"false"; on by default.
    readonly property bool showNowPlaying: String(themeConfig.showNowPlaying) !== "false"
    // Tests inject a player here instead of the Mpris loader; production leaves it undefined.
    property var playerOverride: undefined
    readonly property var nowPlayingPlayer: playerOverride !== undefined ? playerOverride
        : (mprisLoader.item ? mprisLoader.item.player : null)
    readonly property var users: typeof userModel !== "undefined" ? userModel : null
    // Login identity: the skin binds currentUser to its user switch and focusTarget to its field.
    property string currentUser: ""
    property Item focusTarget: null
    // Empty only when the model offers nobody; the field then refuses to submit.
    readonly property string user: currentUser
    readonly property int sessionIndex: typeof sessionModel !== "undefined" && sessionModel && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    // sddm state the auth widgets take.
    readonly property string keyState: typeof sddm !== "undefined" && sddm && sddm.keyState !== undefined ? String(sddm.keyState) : ""
    readonly property string fingerprintState: sessionLock && sddm.fingerprintState !== undefined ? String(sddm.fingerprintState) : ""

    // Design pixels are authored for a 1920x1200 screen, or 1200x1920 on a portrait one: the short
    // and the long side each cap the scale, so a narrow or a tall screen never runs out of room.
    readonly property bool portrait: height > width
    readonly property real uiScale: Math.min(Math.min(width, height) / 1200, Math.max(width, height) / 1920)
    readonly property bool fontsReady: CratePalette.fontsReady
    readonly property bool reduceMotion: CratePalette.reduceMotion
    readonly property bool tokensLinked: CratePalette.tokensLinked
    readonly property string displayFamily: CratePalette.displayFamily
    readonly property string monoFamily: CratePalette.monoFamily

    // Tokens exist only under the Ryoku shell; SDDM never touches them.
    Component.onCompleted: {
        if (sessionLock) CratePalette.linkTokens();
        // The shim drops key PIN requests unless the skin says it draws them (keyState in AuthHint).
        if (sessionLock) sddm.keyPrompts = true;
        if (focusTarget) focusTarget.focusField();
    }

    anchors.fill: parent
    implicitWidth: 1366
    implicitHeight: 768
    clip: true

    Background {
        anchors.fill: parent
        kind: root.themeConfig.background === "sheen" ? "sheen" : "groove"
    }

    // Crate's MPRIS player, session lock only: SDDM never loads the Mpris module.
    Loader {
        id: mprisLoader
        objectName: "mprisLoader"
        active: root.sessionLock && root.showNowPlaying && root.playerOverride === undefined
        source: "NowPlayingMpris.qml"
    }
}
