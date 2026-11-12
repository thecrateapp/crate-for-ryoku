import QtQuick
import Quickshell.Widgets
import shell.services
import Ryoku.Ui.Singletons

// One result: icon or art, title over subtitle, a kind tag or duration at the
// end. The live row takes the theme's wash and a 2 px mark bar.
Item {
    id: row

    property var item: ({})
    property bool live: false
    property bool showTag: false
    property bool showDuration: false

    signal picked()
    signal hovered()

    implicitHeight: Tokens.px(44)

    readonly property string kind: row.item && row.item.kind ? row.item.kind : ""
    readonly property bool crateKind: ["artist", "album", "track", "notice"].indexOf(row.kind) >= 0

    function clock(seconds) {
        const s = Math.max(0, Math.round(seconds || 0));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Rectangle {
        anchors.fill: parent
        color: row.live ? Look.rowWash : "transparent"
    }
    Rectangle {
        visible: row.live
        width: Tokens.px(2)
        radius: width / 2
        color: Look.mark
        anchors { top: parent.top; bottom: parent.bottom; topMargin: Tokens.px(6); bottomMargin: Tokens.px(6) }
    }

    Item {
        id: slot
        width: Tokens.px(30)
        height: Tokens.px(30)
        anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }

        IconImage {
            anchors.centerIn: parent
            visible: row.kind === "app"
            implicitSize: Tokens.px(24)
            source: row.kind === "app" ? Icons.path(row.item.icon, "application-x-executable") : ""
        }
        Glyph {
            anchors.centerIn: parent
            visible: row.kind === "file" || row.kind === "recent"
            name: row.kind === "recent" ? "history" : "document-text"
            tint: Tokens.ink
            size: Tokens.px(22)
        }
        Art {
            anchors.centerIn: parent
            visible: row.crateKind
            size: Tokens.px(30)
            round: row.kind === "artist"
            path: row.item && row.item.art ? row.item.art : ""
            glyph: row.kind === "artist" ? "user" : row.kind === "track" ? "music-note2" : "vinyl-record"
        }
    }

    Column {
        anchors {
            left: slot.right; leftMargin: Tokens.s3
            right: tail.left; rightMargin: Tokens.s3
            verticalCenter: parent.verticalCenter
        }
        spacing: Tokens.px(1)
        Text {
            width: parent.width
            text: row.item && row.item.title ? row.item.title : ""
            color: Tokens.ink
            font.family: Tokens.ui
            font.pixelSize: Tokens.fRow
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: row.item && row.item.subtitle ? row.item.subtitle : ""
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall
            elide: Text.ElideMiddle
        }
    }

    Item {
        id: tail
        width: tailText.implicitWidth
        height: parent.height
        anchors { right: parent.right; rightMargin: Tokens.s4 }
        Text {
            id: tailText
            anchors.verticalCenter: parent.verticalCenter
            text: row.showDuration && row.kind === "track" && row.item.duration ? row.clock(row.item.duration)
                : row.showTag && row.crateKind && row.kind !== "notice" ? I18n.tr(row.kind).toUpperCase()
                : ""
            color: Tokens.inkFaint
            font.family: Look.navFont
            font.pixelSize: Tokens.fTiny
            font.letterSpacing: Look.trackNav
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: row.hovered()
        onClicked: row.picked()
    }
}
