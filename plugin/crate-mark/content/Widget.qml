pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// The bar glyph: the Crate mark, optionally followed by a lowercase "crate"
// label, and Crate's now playing. Its colour follows the active scheme
// (Theme.accent), Crate's own gradient, or the bar ink, per "tone".
// Now playing ("nowPlaying"): "indicator" shows three small cyan bars while
// Crate plays; "track" adds "artist - title"; "off" hides both. The bar's own
// media widget already shows whatever player is active, so the default stays
// small. A click opens the panel and changes nothing.
// Without Crate installed the mark collapses to nothing. (The Ryoku host still
// keeps a few pixels for any plugin slot, so Crate for Ryoku also hides the
// whole slot through `ryoku-shell bar hide crate-mark`; see README.)
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property string tone: (settings && settings.tone) ? String(settings.tone) : "accent"
    readonly property bool showLabel: (settings && settings.showLabel !== undefined) ? !!settings.showLabel : false
    readonly property string nowPlaying: (settings && settings.nowPlaying) ? String(settings.nowPlaying) : "indicator"

    readonly property bool installed: service ? service.installed : true
    readonly property bool playing: service ? service.playing : false
    readonly property bool hasTrack: service ? service.hasTrack : false
    readonly property bool showBars: root.nowPlaying !== "off" && root.playing
    readonly property bool showTrack: root.nowPlaying === "track" && root.hasTrack
    readonly property string trackText: !service ? ""
        : (service.artist ? service.artist + " – " + service.title : service.title)

    implicitWidth: root.installed ? row.implicitWidth : 0
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)
    visible: root.installed

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        CrateLogo {
            anchors.verticalCenter: parent.verticalCenter
            height: 15 * root.s
            brand: root.tone === "brand"
            color: root.tone === "ink" ? Theme.bright : Theme.accent
            opacity: (area.containsMouse || root.open) ? 1.0 : 0.9
        }

        Text {
            visible: root.showLabel
            anchors.verticalCenter: parent.verticalCenter
            text: "crate"
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 12.5 * root.s
            font.letterSpacing: 0.4 * root.s
        }

        // three bars: Crate's "now playing" motif, cyan only while it plays
        Item {
            id: bars
            visible: root.showBars
            anchors.verticalCenter: parent.verticalCenter
            width: 3 * 2 * root.s + 2 * 1.5 * root.s
            height: 11 * root.s

            Repeater {
                model: 3
                Rectangle {
                    id: bar
                    required property int index
                    x: bar.index * 3.5 * root.s
                    width: 2 * root.s
                    radius: 1 * root.s
                    anchors.bottom: parent.bottom
                    color: Theme.accent
                    height: 4 * root.s
                    SequentialAnimation on height {
                        running: root.showBars
                        loops: Animation.Infinite
                        PauseAnimation { duration: bar.index * 140 }
                        NumberAnimation { to: (bar.index === 1 ? 11 : 8) * root.s; duration: 380; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 3 * root.s; duration: 420; easing.type: Easing.InOutSine }
                        NumberAnimation { to: (bar.index === 2 ? 9 : 6) * root.s; duration: 360; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 4 * root.s; duration: 340; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        Text {
            visible: root.showTrack
            anchors.verticalCenter: parent.verticalCenter
            text: root.trackText
            color: root.playing ? Theme.bright : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 12 * root.s
            elide: Text.ElideRight
            // whatever the bar leaves after the mark, the label and the bars
            width: {
                var used = 15 * root.s * 1052 / 1120 + 6 * root.s
                    + (root.showLabel ? 46 * root.s : 0) + (root.showBars ? bars.width + 6 * root.s : 0);
                var cap = 220 * root.s;
                var room = root.widthBudget > 0 ? root.widthBudget - used : cap;
                return Math.max(0, Math.min(implicitWidth, cap, room));
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.installed
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.pluginApi)
                return;
            if (root.open)
                root.requestClose();
            else if (root.pluginApi.togglePanel)
                root.pluginApi.togglePanel();
        }
    }
}
