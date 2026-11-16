import QtQuick
import "../common"
import "../common/i18n"

SkinRoot {
    id: root
    currentUser: userSwitch.currentUser
    focusTarget: passwordField


    // Header: locked state and host on the left, power on the right.
    Row {
        id: headerRow
        objectName: "headerRow"
        readonly property int gap: Math.round(CratePalette.s(10, root.uiScale))
        anchors { left: parent.left; top: parent.top; leftMargin: root.margin; topMargin: Math.round(CratePalette.s(64, root.uiScale)) }
        spacing: gap
        Text {
            id: lockedText
            objectName: "headerLocked"
            text: I18n.tr("locked").toUpperCase()
            color: CratePalette.faint
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
            font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.14
        }
        Text {
            id: headerSep
            visible: root.hostName !== ""
            text: "\u00b7"
            color: CratePalette.cyan
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
        }
        Text {
            objectName: "headerHost"
            visible: root.hostName !== ""
            text: root.hostName
            color: CratePalette.faint
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.max(0, Math.min(implicitWidth, root.width - 2 * root.margin - powerRow.width - Math.round(CratePalette.s(48, root.uiScale))
                - lockedText.width - headerSep.width - 2 * headerRow.gap))
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
            font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.14
        }
    }
    PowerRow {
        id: powerRow
        uiScale: root.uiScale
        anchors { right: parent.right; top: parent.top; rightMargin: root.margin; topMargin: Math.round(CratePalette.s(64, root.uiScale)) }
        onActivated: passwordField.focusField()
    }

    // Date above the clock, bottom-left, clear of the now playing block.
    Column {
        id: clockBlock
        objectName: "clockBlock"
        readonly property int maxWidth: Math.max(0, authColumn.x - root.margin - Math.round(CratePalette.s(48, root.uiScale)))
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: root.margin
            bottomMargin: root.margin + nowPlaying.implicitHeight + Math.round(CratePalette.s(48, root.uiScale)) }
        spacing: Math.round(CratePalette.s(8, root.uiScale))

        Row {
            id: dateRow
            spacing: Math.round(CratePalette.s(8, root.uiScale))
            readonly property string weekday: root.clockLocale.toString(root.now, "dddd").toUpperCase()
            readonly property string rest: root.clockLocale.toString(root.now, "dd MMM yyyy").toUpperCase()
            Text {
                objectName: "dateWeekday"
                text: dateRow.weekday
                color: CratePalette.cyanHi
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(16, root.uiScale))
                font.letterSpacing: Math.round(CratePalette.s(16, root.uiScale)) * 0.14
            }
            Text {
                objectName: "dateSep"
                text: "\u00b7"
                color: CratePalette.cyan
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(16, root.uiScale))
            }
            Text {
                objectName: "dateRest"
                text: dateRow.rest
                color: CratePalette.secondary
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(16, root.uiScale))
                font.letterSpacing: Math.round(CratePalette.s(16, root.uiScale)) * 0.14
            }
        }

        Row {
            id: clock
            objectName: "clock"
            readonly property string marker: root.marker
            readonly property string text: root.clock24h ? root.clockLocale.toString(root.now, "HH:mm")
                : root.clockLocale.toString(root.now, "h:mm AP").replace(marker, "").trim()
            readonly property string ampm: root.clock24h ? "" : marker.toUpperCase()
            spacing: Math.round(CratePalette.s(16, root.uiScale))
            // Five glyphs run to about 2.9 em at Bricolage 800 with tight tracking: shrink to the room
            // left of the auth column, never above s(300).
            readonly property real fitPx: Math.max(Math.round(CratePalette.s(24, root.uiScale)),
                Math.min(Math.round(CratePalette.s(300, root.uiScale)), (clockBlock.maxWidth - (ampmText.visible ? Math.round(CratePalette.s(120, root.uiScale)) : 0)) / 2.9))
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
                font.pixelSize: Math.round(CratePalette.s(28, root.uiScale))
                font.letterSpacing: Math.round(CratePalette.s(28, root.uiScale)) * 0.14
            }
        }
    }

    NowPlaying {
        id: nowPlaying
        uiScale: root.uiScale
        player: root.showNowPlaying ? root.nowPlayingPlayer : null
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: root.margin; bottomMargin: root.margin }
        width: Math.max(0, Math.min(Math.round(CratePalette.s(420, root.uiScale)), authColumn.x - root.margin - Math.round(CratePalette.s(48, root.uiScale))))
    }

    // Bottom right: who is logging in, then the field.
    Column {
        id: authColumn
        objectName: "authColumn"
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: root.margin; bottomMargin: root.margin }
        width: Math.min(Math.round(CratePalette.s(360, root.uiScale)), parent.width - 2 * root.margin)
        spacing: Math.round(CratePalette.s(10, root.uiScale))

        UserSwitch {
            id: userSwitch
            uiScale: root.uiScale
            width: parent.width
            model: root.users
            onActivated: passwordField.focusField()
            label {
                color: CratePalette.text
                font.family: CratePalette.displayFamily
                font.weight: Font.Bold
                font.pixelSize: Math.round(CratePalette.s(28, root.uiScale))
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
            font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
            font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.14
            bottomPadding: Math.round(CratePalette.s(14, root.uiScale))
        }
        Text {
            objectName: "passwordLabel"
            width: parent.width
            text: I18n.tr("password").toUpperCase()
            color: CratePalette.secondary
            elide: Text.ElideRight
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
            font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.14
        }
        PasswordField {
            id: passwordField
            uiScale: root.uiScale
            width: parent.width
            focus: true
            user: root.user
            sessionIndex: root.sessionIndex
            keyState: root.keyState
        }
        ErrorLine { uiScale: root.uiScale; width: parent.width; shown: passwordField.state === "error"; text: passwordField.errorText }
        AuthHint {
            uiScale: root.uiScale
            width: parent.width
            authState: passwordField.state
            keyState: passwordField.keyState
            fingerprintState: root.fingerprintState
        }
    }
}
