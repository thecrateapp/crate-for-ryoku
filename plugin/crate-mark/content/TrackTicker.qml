import QtQuick

Item {
    id: ticker
    required property string text
    required property bool playing
    property alias font: label.font
    property alias color: label.color
    property string textObjectName: ""
    property bool elideWhenStill: false
    property bool continuous: false
    property real scaleFactor: 1
    property color fadeColor: "transparent"

    implicitWidth: Math.ceil(metrics.advanceWidth)
    implicitHeight: label.implicitHeight
    readonly property real overflow: Math.max(0, implicitWidth - width)
    readonly property bool scrolling: visible && playing && width > 0 && overflow > 0
    readonly property real travel: continuous ? implicitWidth + 24 * scaleFactor : overflow
    clip: true

    TextMetrics {
        id: metrics
        font: label.font
        text: ticker.text
    }
    Item {
        id: strip
        width: ticker.implicitWidth
        height: ticker.height

        Text {
            id: label
            objectName: ticker.textObjectName
            anchors.verticalCenter: parent.verticalCenter
            text: ticker.text
            textFormat: Text.PlainText
            width: ticker.elideWhenStill && !ticker.scrolling ? ticker.width : ticker.implicitWidth
            elide: ticker.elideWhenStill && !ticker.scrolling ? Text.ElideRight : Text.ElideNone
        }
        Text {
            visible: ticker.continuous && ticker.scrolling
            x: ticker.travel
            anchors.verticalCenter: parent.verticalCenter
            text: label.text
            textFormat: Text.PlainText
            font: label.font
            color: label.color
        }
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
        roll.stop()
        reading.stop()
        strip.x = 0
        if (scrolling) {
            if (continuous) roll.start()
            else reading.start()
        }
    }
    onScaleFactorChanged: Qt.callLater(reset)
    onTextChanged: Qt.callLater(reset)
    onTravelChanged: Qt.callLater(reset)
    onScrollingChanged: Qt.callLater(reset)
    onContinuousChanged: Qt.callLater(reset)

    // The second copy takes the first one's place at the end of each revolution.
    XAnimator {
        id: roll
        target: strip
        from: 0
        to: -ticker.travel
        duration: Math.max(1, Math.round(ticker.travel * 20 / ticker.scaleFactor))
        easing.type: Easing.Linear
        loops: Animation.Infinite
    }
    SequentialAnimation {
        id: reading
        loops: Animation.Infinite
        PauseAnimation { duration: 2000 }
        XAnimator {
            target: strip
            from: 0
            to: -ticker.travel
            duration: Math.max(100, Math.round(ticker.travel * 20 / ticker.scaleFactor))
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 900 }
        PropertyAction { target: strip; property: "x"; value: 0 }
    }
}
