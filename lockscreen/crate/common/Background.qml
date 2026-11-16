import QtQuick

// Groove or Sheen wallpaper under a veil that keeps text legible.
Item {
    id: root
    objectName: "background"
    property string kind: "groove"
    readonly property url source: Qt.resolvedUrl("backgrounds/" + (kind === "sheen" ? "sheen" : "groove") + ".webp")

    Rectangle { anchors.fill: parent; color: "#0a0a0f" }
    Image {
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: 1920
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(10 / 255, 10 / 255, 15 / 255, 0.35) }
}
