import QtQuick

// One filled Solar icon (480 Design, CC BY 4.0) on Solar's 24-unit grid: the
// Bold and Outline weights Crate's player controls use (@crate/ui
// icons/media.tsx). `path` is the icon's SVG path data; `evenOdd` for the
// Outline weight, whose shapes are rings cut out of a fill. Painted with a 2D
// Canvas (antialiased, cheap to create) rather than a Shape, which has to
// triangulate these curves every time the panel opens.
Canvas {
    id: root

    property string path: ""
    property color color: "white"
    property bool evenOdd: false

    implicitWidth: 16
    implicitHeight: 16
    renderStrategy: Canvas.Cooperative

    onPathChanged: requestPaint()
    onColorChanged: requestPaint()
    onEvenOddChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (!root.path)
            return;
        var k = Math.min(width, height) / 24;
        ctx.scale(k, k);
        ctx.fillStyle = root.color;
        ctx.fillRule = root.evenOdd ? Qt.OddEvenFill : Qt.WindingFill;
        ctx.path = root.path;
        ctx.fill();
    }
}
