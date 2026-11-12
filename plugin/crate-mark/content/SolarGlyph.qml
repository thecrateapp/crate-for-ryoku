import QtQuick
import QtQuick.Shapes

// One Solar icon (480 Design, CC BY 4.0; the set Crate's UI uses through
// @solar-icons/react), drawn as stroked vector paths on Solar's 24-unit grid.
// `path` is the icon's SVG path data; size it with width/height.
Item {
    id: root

    property string path: ""
    property color color: "white"
    property real strokeWidth: 1.5   // in Solar's 24-unit grid

    implicitWidth: 16
    implicitHeight: 16

    Shape {
        width: 24
        height: 24
        scale: Math.min(root.width, root.height) / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
