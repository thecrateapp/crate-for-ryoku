import QtQuick

// Mono uppercase label with Crate's hover underline: 1 px cyan-hi, scaleX 0 to 1 from the left.
// Never takes focus; the host returns focus to the password field on `activated`.
Item {
    id: root
    // Design pixels scale per skin instance: the host binds this to its own height / 1200.
    property real uiScale: 1
    property string text: ""
    property bool interactive: true
    property bool reduceMotion: CratePalette.reduceMotion
    readonly property bool hovered: area.containsMouse && interactive
    property alias label: label
    signal activated()

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + Math.round(CratePalette.s(4, root.uiScale))

    Text {
        id: label
        width: parent.width
        text: root.text
        elide: Text.ElideRight
        maximumLineCount: 1
        color: root.hovered ? CratePalette.text : CratePalette.secondary
        font.family: CratePalette.monoFamily
        font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
        font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.14
        font.capitalization: Font.AllUppercase
    }
    Rectangle {
        id: underline
        objectName: "underline"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: CratePalette.cyanHi
        transform: Scale { id: sc; origin.x: 0; origin.y: 0; xScale: root.hovered ? 1 : 0
            Behavior on xScale { enabled: !root.reduceMotion; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
    }
    MouseArea {
        id: area
        objectName: "hoverArea"
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.onPressAction: root.activated()
}
