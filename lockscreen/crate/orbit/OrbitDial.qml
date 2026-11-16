import QtQuick
import "../common"

// Minute dial: 60 ticks, a mono number every five, turning so the current minute sits at three
// o'clock. The host places it so its left part bleeds off the screen. The square `root` never
// rotates (its bounds stay true); only `ring` turns.
Item {
    id: root
    objectName: "orbitDial"
    // Design pixels scale per skin instance: the host binds this to its own height / 1200.
    property real uiScale: 1
    property int minutes: 0
    property bool reduceMotion: CratePalette.reduceMotion

    readonly property int tickCount: 60
    readonly property real radius: width / 2
    // Minute m sits m * 6 degrees clockwise from three o'clock; turning by -minutes * 6 brings the current one to three o'clock.
    readonly property real targetRotation: -(minutes / 60) * 360
    readonly property real ringRotation: ring.rotation

    height: width

    Item {
        id: ring
        anchors.fill: parent
        rotation: root.targetRotation
        // The short way round, so :59 to :00 does not unwind the whole dial.
        Behavior on rotation {
            enabled: !root.reduceMotion
            RotationAnimation { direction: RotationAnimation.Counterclockwise; duration: 600; easing.type: Easing.OutCubic }
        }

        Rectangle {
            objectName: "dialRing"
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: CratePalette.hairline
        }

        Repeater {
            model: root.tickCount
            delegate: Item {
                id: tickSlot
                required property int index
                readonly property bool current: index === root.minutes
                readonly property bool major: index % 5 === 0
                x: root.radius; y: root.radius
                width: 0; height: 0
                rotation: index * 6
                Rectangle {
                    objectName: "tick" + tickSlot.index
                    readonly property real len: Math.round(CratePalette.s(tickSlot.current ? 44 : tickSlot.major ? 28 : 14, root.uiScale))
                    x: root.radius - len
                    height: tickSlot.current ? Math.max(2, Math.round(CratePalette.s(3, root.uiScale))) : tickSlot.major ? 2 : 1
                    y: -height / 2
                    width: len
                    color: tickSlot.current ? CratePalette.cyanHi : tickSlot.major ? CratePalette.secondary : CratePalette.faint
                }
            }
        }

        Repeater {
            model: 12
            delegate: Item {
                id: numSlot
                required property int index
                readonly property int minute: index * 5
                x: root.radius; y: root.radius
                width: 0; height: 0
                rotation: minute * 6
                Text {
                    objectName: "dialNumber" + numSlot.minute
                    text: (numSlot.minute < 10 ? "0" : "") + numSlot.minute
                    color: numSlot.minute === root.minutes ? CratePalette.cyanHi : CratePalette.faint
                    font.family: CratePalette.monoFamily
                    font.pixelSize: Math.round(CratePalette.s(13, root.uiScale))
                    font.letterSpacing: Math.round(CratePalette.s(13, root.uiScale)) * 0.12
                    x: root.radius - Math.round(CratePalette.s(70, root.uiScale)) - width / 2
                    y: -height / 2
                    transformOrigin: Item.Center
                    // Numbers stay upright while the ring turns.
                    rotation: -(numSlot.minute * 6 + ring.rotation)
                }
            }
        }
    }
}
