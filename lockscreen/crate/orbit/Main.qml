import QtQuick
import "../common"
import "../common/i18n"

SkinRoot {
    id: root
    currentUser: userSwitch.currentUser
    focusTarget: passwordField


    // Design geometry at 1200 px of height: the dial centre and radius, in skin pixels.
    readonly property real dialRadius: Math.round(CratePalette.s(440, root.uiScale))
    readonly property real dialCx: Math.round(CratePalette.s(250, root.uiScale))
    readonly property real dialCy: root.height / 2
    readonly property real infoX: dialCx + dialRadius + Math.round(CratePalette.s(32, root.uiScale))

    OrbitDial {
        id: dial
        uiScale: root.uiScale
        width: root.dialRadius * 2
        x: root.dialCx - root.dialRadius
        y: root.dialCy - root.dialRadius
        minutes: root.now.getMinutes()
    }

    Text {
        id: hourText
        objectName: "hourText"
        text: root.hourDigits
        color: CratePalette.text
        font.family: CratePalette.displayFamily
        font.weight: 800
        font.pixelSize: Math.round(CratePalette.s(300, root.uiScale))
        font.letterSpacing: -Math.round(CratePalette.s(300, root.uiScale)) * 0.03
        x: root.dialCx - width / 2
        y: root.dialCy - height / 2
    }
    Text {
        objectName: "clockAmPm"
        visible: !root.clock24h
        text: root.marker.toUpperCase()
        color: CratePalette.cyanHi
        font.family: CratePalette.monoFamily
        font.pixelSize: Math.round(CratePalette.s(24, root.uiScale))
        font.letterSpacing: Math.round(CratePalette.s(24, root.uiScale)) * 0.14
        x: root.dialCx - width / 2
        y: hourText.y + hourText.height - Math.round(CratePalette.s(40, root.uiScale))
    }

    // Beside the current-minute tick: the minutes, then the date.
    Column {
        id: info
        objectName: "orbitInfo"
        x: root.infoX
        y: root.dialCy - height / 2
        spacing: Math.round(CratePalette.s(10, root.uiScale))
        Text {
            id: minuteLabel
            objectName: "minuteLabel"
            text: root.clockLocale.toString(root.now, "mm")
            color: CratePalette.cyan
            font.family: CratePalette.monoFamily
            font.pixelSize: Math.round(CratePalette.s(72, root.uiScale))
            font.letterSpacing: Math.round(CratePalette.s(72, root.uiScale)) * 0.14
        }
        Row {
            id: dateBlock
            objectName: "dateBlock"
            readonly property int maxWidth: Math.max(0, authColumn.x - root.infoX - Math.round(CratePalette.s(48, root.uiScale)))
            spacing: Math.round(CratePalette.s(10, root.uiScale))
            Text {
                id: weekday
                objectName: "dateWeekday"
                text: root.clockLocale.toString(root.now, "dddd").toUpperCase()
                color: CratePalette.text
                font.family: CratePalette.displayFamily
                font.weight: Font.Bold
                font.pixelSize: Math.round(CratePalette.s(22, root.uiScale))
                font.letterSpacing: Math.round(CratePalette.s(22, root.uiScale)) * 0.06
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, dateBlock.maxWidth)
            }
            Text {
                objectName: "dateRest"
                text: root.clockLocale.toString(root.now, "dd MMM yyyy").toUpperCase()
                color: CratePalette.secondary
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(16, root.uiScale))
                font.letterSpacing: Math.round(CratePalette.s(16, root.uiScale)) * 0.14
                anchors.baseline: weekday.baseline
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.max(0, Math.min(implicitWidth, dateBlock.maxWidth - weekday.width - dateBlock.spacing))
                visible: width > 0
            }
        }
    }

    // Top right: power links with hairline rules between them.
    PowerRow {
        id: powerRow
        uiScale: root.uiScale
        anchors { right: parent.right; top: parent.top; rightMargin: root.margin; topMargin: Math.round(CratePalette.s(64, root.uiScale)) }
        onActivated: passwordField.focusField()
    }
    Repeater {
        model: 2
        delegate: Rectangle {
            required property int index
            objectName: "powerSep" + index
            readonly property Item prev: powerRow.children[index]
            x: powerRow.x + prev.x + prev.width + powerRow.spacing / 2 - 0.5
            y: powerRow.y
            width: 1
            height: powerRow.height
            color: CratePalette.hairline
        }
    }

    // One discreet line, bottom left.
    NowPlaying {
        id: nowPlaying
        uiScale: root.uiScale
        compact: true
        player: root.showNowPlaying ? root.nowPlayingPlayer : null
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: root.margin; bottomMargin: root.margin }
        width: Math.max(0, Math.min(Math.round(CratePalette.s(520, root.uiScale)), authColumn.x - root.margin - Math.round(CratePalette.s(48, root.uiScale))))
    }

    // Bottom right, right-aligned: who, the field, Unlock, then what went wrong.
    Column {
        id: authColumn
        objectName: "authColumn"
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: root.margin; bottomMargin: root.margin }
        width: Math.min(Math.round(CratePalette.s(360, root.uiScale)), parent.width - 2 * root.margin)
        spacing: Math.round(CratePalette.s(12, root.uiScale))

        UserSwitch {
            id: userSwitch
            uiScale: root.uiScale
            width: parent.width
            model: root.users
            onActivated: passwordField.focusField()
            label {
                color: CratePalette.text
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(16, root.uiScale))
                font.letterSpacing: Math.round(CratePalette.s(16, root.uiScale)) * 0.2
                horizontalAlignment: Text.AlignRight
            }
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
        Binding { target: passwordField.input; property: "horizontalAlignment"; value: TextInput.AlignRight }
        Item {
            id: unlockAction
            objectName: "unlockAction"
            x: parent.width - width
            width: unlockRow.width
            height: unlockLink.implicitHeight
            Row {
                id: unlockRow
                spacing: Math.round(CratePalette.s(10, root.uiScale))
                HoverLink {
                    id: unlockLink
                    objectName: "unlockLink"
                    uiScale: root.uiScale
                    text: I18n.tr("Unlock")
                    interactive: passwordField.text !== "" && passwordField.state !== "checking"
                    opacity: interactive ? 1 : 0.55
                    onActivated: { passwordField.submit(); passwordField.focusField(); }
                }
                Rectangle {
                    objectName: "unlockMark"
                    anchors.verticalCenter: unlockLink.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(CratePalette.s(2, root.uiScale))
                    width: Math.round(CratePalette.s(7, root.uiScale)); height: width
                    radius: 1
                    color: CratePalette.cyan
                }
            }
        }
        Item {
            width: parent.width
            height: denied.implicitHeight
            Text {
                id: denied
                objectName: "accessDenied"
                anchors.right: parent.right
                visible: passwordField.state === "error"
                text: I18n.tr("ACCESS DENIED")
                color: CratePalette.danger
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
                font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.14
            }
        }
        AuthHint {
            uiScale: root.uiScale
            width: parent.width
            horizontalAlignment: Text.AlignRight
            authState: passwordField.state
            keyState: passwordField.keyState
            fingerprintState: root.fingerprintState
        }
    }
}
