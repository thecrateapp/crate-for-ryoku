import QtQuick

// The bar and panel use the same reading pauses and scroll speed as QS Bar's media widget.
Item {
    id: ticker
    required property string text
    required property bool playing
    property alias font: label.font
    property alias color: label.color
    property string textObjectName: ""
    property bool elideWhenStill: false
    property real scaleFactor: 1
    property color fadeColor: "transparent"

    implicitWidth: Math.ceil(metrics.advanceWidth)
    implicitHeight: label.implicitHeight
    readonly property real overflow: Math.max(0, implicitWidth - width)
    readonly property bool scrolling: visible && playing && width > 0 && overflow > 0
    clip: true

    TextMetrics {
        id: metrics
        font: label.font
        text: ticker.text
    }
    Text {
        id: label
        objectName: ticker.textObjectName
        anchors.verticalCenter: parent.verticalCenter
        text: ticker.text
        textFormat: Text.PlainText
        width: ticker.elideWhenStill && !ticker.scrolling ? ticker.width : ticker.implicitWidth
        elide: ticker.elideWhenStill && !ticker.scrolling ? Text.ElideRight : Text.ElideNone
    }

    Rectangle {
        visible: ticker.overflow > 0 && ticker.fadeColor.a > 0
        anchors.right: parent.right
        width: Math.min(parent.width, 28)
        height: parent.height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: ticker.fadeColor }
        }
    }

    function reset() {
        animation.stop()
        label.x = 0
        if (ticker.scrolling)
            animation.start()
    }
    onTextChanged: Qt.callLater(reset)
    onOverflowChanged: Qt.callLater(reset)
    onScrollingChanged: Qt.callLater(reset)

    SequentialAnimation {
        id: animation
        loops: Animation.Infinite
        PauseAnimation { duration: 2000 }
        NumberAnimation {
            target: label
            property: "x"
            to: -ticker.overflow
            duration: Math.max(100, ticker.overflow / ticker.scaleFactor * 20)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 900 }
        PropertyAction { target: label; property: "x"; value: 0 }
    }
}
