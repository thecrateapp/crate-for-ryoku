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
    // Production ticks `now` once a second; tests pin it.
    property bool liveClock: true
    readonly property string hostName: typeof sddm !== "undefined" && sddm && sddm.hostName ? String(sddm.hostName) : ""
    readonly property int margin: Math.round(CratePalette.s(96))
    Timer {
        interval: 1000; repeat: true; running: root.liveClock
        onTriggered: root.now = new Date()
    }
    // theme.conf `showNowPlaying` is the string "true"/"false"; on by default.
    readonly property bool showNowPlaying: String(themeConfig.showNowPlaying) !== "false"
    // Tests inject a player here instead of the Mpris loader; production leaves it undefined.
    property var playerOverride: undefined
    readonly property var nowPlayingPlayer: playerOverride !== undefined ? playerOverride
        : (mprisLoader.item ? mprisLoader.item.player : null)
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

    // Header: locked state and host on the left, power on the right.
    Row {
        id: headerRow
        objectName: "headerRow"
        readonly property int gap: Math.round(CratePalette.s(10))
        anchors { left: parent.left; top: parent.top; leftMargin: root.margin; topMargin: Math.round(CratePalette.s(64)) }
        spacing: gap
        Text {
            id: lockedText
            objectName: "headerLocked"
            text: I18n.tr("locked").toUpperCase()
            color: CratePalette.faint
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12))
            font.letterSpacing: Math.round(CratePalette.s(12)) * 0.14
        }
        Text {
            id: headerSep
            visible: root.hostName !== ""
            text: "\u00b7"
            color: CratePalette.cyan
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12))
        }
        Text {
            objectName: "headerHost"
            visible: root.hostName !== ""
            text: root.hostName
            color: CratePalette.faint
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.max(0, Math.min(implicitWidth, root.width - 2 * root.margin - powerRow.width - Math.round(CratePalette.s(48))
                - lockedText.width - headerSep.width - 2 * headerRow.gap))
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12))
            font.letterSpacing: Math.round(CratePalette.s(12)) * 0.14
        }
    }
    PowerRow {
        id: powerRow
        anchors { right: parent.right; top: parent.top; rightMargin: root.margin; topMargin: Math.round(CratePalette.s(64)) }
        onActivated: passwordField.focusField()
    }

    // Date above the clock, bottom-left, clear of the now playing block.
    Column {
        id: clockBlock
        objectName: "clockBlock"
        readonly property int maxWidth: Math.max(0, authColumn.x - root.margin - Math.round(CratePalette.s(48)))
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: root.margin
            bottomMargin: root.margin + nowPlaying.implicitHeight + Math.round(CratePalette.s(48)) }
        spacing: Math.round(CratePalette.s(8))

        Row {
            id: dateRow
            spacing: Math.round(CratePalette.s(8))
            readonly property string weekday: root.clockLocale.toString(root.now, "dddd").toUpperCase()
            readonly property string rest: root.clockLocale.toString(root.now, "dd MMM yyyy").toUpperCase()
            Text {
                objectName: "dateWeekday"
                text: dateRow.weekday
                color: CratePalette.cyanHi
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(16))
                font.letterSpacing: Math.round(CratePalette.s(16)) * 0.14
            }
            Text {
                objectName: "dateSep"
                text: "\u00b7"
                color: CratePalette.cyan
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(16))
            }
            Text {
                objectName: "dateRest"
                text: dateRow.rest
                color: CratePalette.secondary
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(16))
                font.letterSpacing: Math.round(CratePalette.s(16)) * 0.14
            }
        }

        Row {
            id: clock
            objectName: "clock"
            // "h" only means a 12 hour clock when the format also has AP; the marker is cut back out of the digits.
            readonly property string marker: root.clockLocale.toString(root.now, "AP")
            readonly property string text: root.clock24h ? root.clockLocale.toString(root.now, "HH:mm")
                : root.clockLocale.toString(root.now, "h:mm AP").replace(marker, "").trim()
            readonly property string ampm: root.clock24h ? "" : marker.toUpperCase()
            spacing: Math.round(CratePalette.s(16))
            // Five glyphs run to about 2.9 em at Bricolage 800 with tight tracking: shrink to the room
            // left of the auth column, never above s(300).
            readonly property real fitPx: Math.max(Math.round(CratePalette.s(60)),
                Math.min(Math.round(CratePalette.s(300)), (clockBlock.maxWidth - (ampmText.visible ? Math.round(CratePalette.s(120)) : 0)) / 2.9))
            height: Math.round(fitPx * 1.2)
            Repeater {
                model: clock.text.length
                delegate: Item {
                    id: slot
                    objectName: "clockSlot" + index
                    readonly property string ch: clock.text.charAt(index)
                    property string shown: ch
                    property bool sliding: false
                    // 0 to 1 across the slide; the old glyph leaves upward as the new one rises in.
                    property real progress: 1
                    readonly property int slideDuration: CratePalette.reduceMotion ? 0 : 120
                    width: cur.implicitWidth
                    height: clock.height
                    clip: true
                    onChChanged: {
                        if (slideDuration > 0 && ch !== shown) {
                            outgoing.text = shown;
                            sliding = true;
                            progress = 0;
                            slide.restart();
                        }
                        shown = ch;
                    }
                    Text {
                        id: cur
                        text: slot.shown
                        color: CratePalette.text
                        font.family: CratePalette.displayFamily
                        font.weight: 800
                        font.pixelSize: clock.fitPx
                        font.letterSpacing: -clock.fitPx * 0.03
                        y: (1 - slot.progress) * clock.height * 0.5
                        opacity: slot.progress
                    }
                    Text {
                        id: outgoing
                        visible: slot.sliding
                        color: CratePalette.text
                        font: cur.font
                        y: -slot.progress * clock.height * 0.5
                        opacity: 1 - slot.progress
                    }
                    NumberAnimation {
                        id: slide
                        target: slot; property: "progress"; from: 0; to: 1
                        duration: slot.slideDuration; easing.type: Easing.OutCubic
                        onFinished: slot.sliding = false
                    }
                }
            }
            Text {
                id: ampmText
                objectName: "clockAmPm"
                visible: !root.clock24h
                text: clock.ampm
                color: CratePalette.cyanHi
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(28))
                font.letterSpacing: Math.round(CratePalette.s(28)) * 0.14
            }
        }
    }

    NowPlaying {
        id: nowPlaying
        player: root.showNowPlaying ? root.nowPlayingPlayer : null
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: root.margin; bottomMargin: root.margin }
        width: Math.max(0, Math.min(Math.round(CratePalette.s(420)), authColumn.x - root.margin - Math.round(CratePalette.s(48))))
    }

    // Crate's MPRIS player, session lock only: SDDM never loads the Mpris module.
    Loader {
        id: mprisLoader
        objectName: "mprisLoader"
        active: root.sessionLock && root.showNowPlaying && root.playerOverride === undefined
        source: "../common/NowPlayingMpris.qml"
    }

    // Bottom right: who is logging in, then the field.
    Column {
        id: authColumn
        objectName: "authColumn"
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: root.margin; bottomMargin: root.margin }
        width: Math.min(Math.round(CratePalette.s(360)), parent.width - 2 * root.margin)
        spacing: Math.round(CratePalette.s(10))

        UserSwitch {
            id: userSwitch
            width: parent.width
            model: root.users
            onActivated: passwordField.focusField()
            label {
                color: CratePalette.text
                font.family: CratePalette.displayFamily
                font.weight: Font.Bold
                font.pixelSize: Math.round(CratePalette.s(28))
                font.letterSpacing: 0
                font.capitalization: Font.MixedCase
            }
        }
        Text {
            objectName: "userAddress"
            width: parent.width
            text: root.user + (root.hostName !== "" ? "@" + root.hostName : "")
            color: CratePalette.faint
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12))
            font.letterSpacing: Math.round(CratePalette.s(12)) * 0.14
            bottomPadding: Math.round(CratePalette.s(14))
        }
        Text {
            objectName: "passwordLabel"
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
        ErrorLine { width: parent.width; shown: passwordField.state === "error"; text: passwordField.errorText }
        AuthHint {
            width: parent.width
            authState: passwordField.state
            keyState: passwordField.keyState
            fingerprintState: root.sessionLock && sddm.fingerprintState !== undefined ? String(sddm.fingerprintState) : ""
        }
    }
}
