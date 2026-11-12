import QtQuick
import QtQuick.Shapes

// The Crate mark, drawn from the logo's outline path (app/web/public/icons/logo.svg,
// the g1 layer) so it stays a crisp vector at any bar scale and needs no image
// asset. Set height; the width follows the logo's 1052:1120 aspect.
// brand: true paints Crate's own cyan gradient; otherwise the mark is one flat
// colour (the bar passes the themed accent or ink).
Item {
    id: root

    property color color: "#06b6d4"
    property bool brand: false

    implicitHeight: 16
    implicitWidth: height * 1052 / 1120
    width: implicitWidth

    Shape {
        width: 1052
        height: 1120
        scale: root.height / 1120
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillRule: ShapePath.WindingFill
            fillColor: root.color
            fillGradient: root.brand ? brandGradient : null

            PathSvg {
                path: "M990.4,249.2l-403-232.7C568.4,5.5,547.2,0,525.9,0c-21.2,0-42.4,5.5-61.5,16.5l-403,232.7C23.4,271.1,0,311.7,0,355.6v261.7v58.2V821c0,43.9,23.4,84.5,61.5,106.4c0,0,201.7,116.5,319.8,184.6c35.4,20.5,79.3-3.1,83-42.7l0.3-5.5v-20.6V395l61.4-35.4l61.4,35.4v648.2v20.6l0.3,5.5c3.8,39.5,47.6,63.1,83,42.7c118.1-68.2,319.8-184.6,319.8-184.6c38-22,61.5-62.5,61.5-106.4V675.5v-58.2V355.6C1051.9,311.7,1028.4,271.1,990.4,249.2z M363.4,984.8L112.1,839.7c-6.7-3.9-10.8-11-10.8-18.8V675.5v-58.2c0-7.7,4.2-14.9,10.8-18.8l251.3-145.1V984.8z M101.2,487.9V355.6c0-7.7,4.1-14.9,10.8-18.8l403-232.7c3.3-1.9,7-2.9,10.8-2.9c3.8,0,7.5,1,10.8,2.9l403,232.7c6.7,3.9,10.8,11,10.8,18.8v132.3L525.9,242.7L101.2,487.9z M950.6,821c0,7.7-4.1,14.9-10.8,18.8L688.5,984.8V453.5l251.3,145.1c6.7,3.9,10.8,11.1,10.8,18.8v58.2V821z"
            }
        }

        LinearGradient {
            id: brandGradient
            x1: 226.95; y1: -47.06
            x2: 815.94; y2: 1204.54
            GradientStop { position: 0; color: "#67e8f9" }
            GradientStop { position: 1; color: "#0e7490" }
        }
    }
}
