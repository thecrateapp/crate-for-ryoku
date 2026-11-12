import QtQuick
import Quickshell.Widgets
import Ryoku.Ui.Singletons

// The picture beside a Crate row: the cached photo or cover when the app gave a
// file path, else a Solar glyph on a faint tile. Artists are round.
ClippingRectangle {
    id: art

    property string path: ""
    property string glyph: "vinyl-record"
    property bool round: false
    property int size: 30

    width: art.size
    height: art.size
    radius: art.round ? art.size / 2 : Tokens.px(4)
    color: Tokens.tint5

    Image {
        id: picture
        anchors.fill: parent
        visible: status === Image.Ready
        source: art.path.length ? "file://" + art.path : ""
        sourceSize: Qt.size(art.size * 2, art.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
    Glyph {
        anchors.centerIn: parent
        visible: !picture.visible
        name: art.glyph
        tint: Tokens.inkDim
        size: Math.round(art.size * (art.size > 48 ? 0.3 : 0.55))
    }
}
