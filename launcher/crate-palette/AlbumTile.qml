import QtQuick
import Ryoku.Ui.Singletons

// An album in the Crate grid: a large cover over its title and artist.
Item {
    id: tile

    property var item: ({})
    property bool live: false

    signal picked()
    signal hovered()

    implicitHeight: cover.height + Tokens.s2 + label.implicitHeight

    Art {
        id: cover
        width: tile.width
        height: tile.width
        size: tile.width
        path: tile.item && tile.item.art ? tile.item.art : ""
        glyph: "vinyl-record"
    }
    Rectangle {
        anchors.fill: cover
        color: "transparent"
        radius: cover.radius
        border.width: tile.live ? Tokens.px(2) : 0
        border.color: Look.mark
    }
    Column {
        id: label
        width: tile.width
        anchors { top: cover.bottom; topMargin: Tokens.s2 }
        Text {
            width: parent.width
            text: tile.item && tile.item.title ? tile.item.title : ""
            color: tile.live ? Look.mark : Tokens.ink
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: tile.item && tile.item.subtitle ? tile.item.subtitle : ""
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fTiny
            elide: Text.ElideRight
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tile.hovered()
        onClicked: tile.picked()
    }
}
