import QtQuick
import QtQuick.Effects
import "i18n"

// Now playing block. `player` is a plain object with title, artist, artUrl, position, length
// (seconds) and playing, or null. Hidden unless a player is playing. `compact` draws one mono
// line (orbit); otherwise the hero block: hairline rule, cover, title, artist, progress.
Item {
    id: root
    objectName: "nowPlaying"

    property var player: null
    property bool compact: false

    readonly property bool active: !!player && player.playing === true
    readonly property string title: player ? String(player.title || "") : ""
    readonly property string artist: player ? String(player.artist || "") : ""
    readonly property string artUrl: player ? String(player.artUrl || "") : ""
    readonly property real fraction: {
        if (!player) return 0;
        var len = Number(player.length), pos = Number(player.position);
        if (!(len > 0) || !(pos >= 0)) return 0;
        return Math.min(1, pos / len);
    }

    visible: active
    implicitWidth: Math.round(CratePalette.s(420))
    implicitHeight: compact ? line.implicitHeight : hero.implicitHeight
    height: implicitHeight

    Text {
        id: line
        objectName: "nowPlayingLine"
        visible: root.compact
        width: parent.width
        maximumLineCount: 1
        elide: Text.ElideRight
        text: I18n.tr("nowPlaying").toUpperCase()
            + (root.artist !== "" || root.title !== "" ? " · " : "")
            + root.artist + (root.artist !== "" && root.title !== "" ? " — " : "") + root.title
        color: CratePalette.secondary
        font.family: CratePalette.monoFamily
        font.pixelSize: Math.round(CratePalette.s(12))
        font.letterSpacing: Math.round(CratePalette.s(12)) * 0.14
    }

    Item {
        id: hero
        visible: !root.compact
        width: parent.width
        implicitHeight: rule.height + body.anchors.topMargin + body.height + progress.anchors.topMargin + progress.height

        Rectangle {
            id: rule
            objectName: "nowPlayingRule"
            width: parent.width
            height: 1
            color: CratePalette.hairline
        }
        Row {
            id: body
            anchors { top: rule.bottom; topMargin: Math.round(CratePalette.s(16)) }
            width: parent.width
            spacing: Math.round(CratePalette.s(16))

            Item {
                id: cover
                objectName: "nowPlayingCover"
                width: Math.round(CratePalette.s(72)); height: width
                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: CratePalette.radius
                    color: "black"
                    visible: false
                    layer.enabled: true
                }
                Rectangle {
                    anchors.fill: parent
                    radius: CratePalette.radius
                    color: Qt.rgba(241 / 255, 245 / 255, 249 / 255, 0.06)
                    border.width: 1
                    border.color: CratePalette.hairline
                    visible: art.status !== Image.Ready
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(width * 2, height * 2)
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }
            }
            Column {
                width: parent.width - cover.width - parent.spacing
                anchors.verticalCenter: cover.verticalCenter
                spacing: Math.round(CratePalette.s(4))

                Text {
                    width: parent.width
                    text: I18n.tr("nowPlayingInCrate").toUpperCase()
                    color: CratePalette.faint
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: CratePalette.monoFamily
                    font.pixelSize: Math.round(CratePalette.s(11))
                    font.letterSpacing: Math.round(CratePalette.s(11)) * 0.14
                }
                Text {
                    objectName: "nowPlayingTitle"
                    width: parent.width
                    text: root.title
                    color: CratePalette.text
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: CratePalette.displayFamily
                    font.weight: Font.Bold
                    font.pixelSize: Math.round(CratePalette.s(22))
                }
                Text {
                    objectName: "nowPlayingArtist"
                    width: parent.width
                    text: root.artist
                    color: CratePalette.secondary
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Math.round(CratePalette.s(14))
                }
            }
        }
        Rectangle {
            id: progress
            objectName: "nowPlayingTrack"
            anchors { top: body.bottom; topMargin: Math.round(CratePalette.s(14)) }
            width: parent.width
            height: Math.max(2, Math.round(CratePalette.s(2)))
            color: CratePalette.hairline
            Rectangle {
                objectName: "nowPlayingProgress"
                height: parent.height
                width: parent.width * root.fraction
                color: CratePalette.cyanHi
            }
        }
    }
}
