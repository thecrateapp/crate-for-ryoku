import QtQuick
import "lib/glyphs.js" as Glyphs

// A Solar line-duotone glyph drawn in one colour from Tokens.
Image {
    id: glyph

    property string name: ""
    property color tint: "white"
    property int size: 20

    width: glyph.size
    height: glyph.size
    sourceSize: Qt.size(glyph.size * 2, glyph.size * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    readonly property string markup: Glyphs.svg(glyph.name, String(glyph.tint))
    source: glyph.markup.length ? "data:image/svg+xml;utf8," + encodeURIComponent(glyph.markup) : ""
}
