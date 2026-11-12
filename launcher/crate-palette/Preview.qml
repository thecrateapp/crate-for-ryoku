import QtQuick
import Ryoku.Ui.Singletons

// The still Settings > App Launcher shows for Crate Palette: the field, the
// tabs and a few grouped rows. QtQuick and Ryoku.Ui only; it starts nothing.
Item {
    id: preview

    property var settings: ({})
    signal editRequested(string key, var value)

    implicitWidth: 720
    implicitHeight: 250

    readonly property color mark: Tokens.mark !== undefined ? Tokens.mark : Tokens.ink
    readonly property color caption: Tokens.caption !== undefined ? Tokens.caption : Tokens.inkFaint
    readonly property color wash: Tokens.rowWash !== undefined ? Tokens.rowWash : Tokens.tint10
    readonly property string nav: Tokens.navFont !== undefined ? Tokens.navFont : Tokens.ui

    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
    }

    Rectangle {
        width: 440
        height: 222
        anchors.centerIn: parent
        radius: Tokens.radius
        color: Tokens.paperLift
        border.width: 1
        border.color: Tokens.line
        clip: true

        Column {
            width: parent.width

            Item {
                width: parent.width
                height: 38
                Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "rep"
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: 15
                }
                Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: preview.mark }
            }
            Item {
                width: parent.width
                height: 26
                Row {
                    x: 14
                    height: parent.height
                    spacing: 16
                    Repeater {
                        model: ["ALL", "APPS", "FILES", "CRATE", "REC"]
                        delegate: Item {
                            required property string modelData
                            required property int index
                            width: label.implicitWidth
                            height: parent.height
                            Text {
                                id: label
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.modelData
                                color: parent.index === 0 ? preview.mark : Tokens.inkFaint
                                font.family: preview.nav
                                font.pixelSize: 9
                                font.letterSpacing: 1.2
                            }
                            Rectangle {
                                visible: parent.index === 0
                                width: parent.width; height: 2
                                anchors.bottom: parent.bottom
                                color: preview.mark
                            }
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: Tokens.line }
            }
            Repeater {
                model: [
                    { cap: "APPS", title: "Report Viewer", sub: "Office", live: true },
                    { cap: "FILES", title: "report-q3.pdf", sub: "~/Documents", live: false },
                    { cap: "CRATE", title: "Repion", sub: "Artist", live: false }
                ]
                delegate: Column {
                    required property var modelData
                    width: 440
                    Text {
                        x: 14
                        topPadding: 6
                        text: parent.modelData.cap
                        color: preview.caption
                        font.family: preview.nav
                        font.pixelSize: 8
                        font.letterSpacing: 1.2
                    }
                    Rectangle {
                        width: parent.width
                        height: 30
                        color: parent.modelData.live ? preview.wash : "transparent"
                        Rectangle { visible: parent.parent.modelData.live; width: 2; height: 18; anchors.verticalCenter: parent.verticalCenter; color: preview.mark }
                        Text {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.modelData.title + "   " + parent.parent.modelData.sub
                            color: Tokens.ink
                            font.family: Tokens.ui
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
