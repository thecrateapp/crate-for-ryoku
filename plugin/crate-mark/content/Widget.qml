pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// Crate mark, playing bars and a width-budgeted artist/title ticker.
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
    readonly property string nowPlaying: (settings && settings.nowPlaying) ? String(settings.nowPlaying) : "track"

    readonly property bool installed: service ? service.installed : true
    readonly property bool playing: service ? service.playing : false
    readonly property bool hasTrack: service ? service.hasTrack : false
    readonly property real budget: widthBudget > 0 ? widthBudget : 220 * s
    readonly property bool showBars: root.nowPlaying !== "off" && root.playing
    readonly property bool showTrack: root.nowPlaying === "track" && root.hasTrack && !service.stopped
    readonly property bool canAnimate: root.active && root.visible && !(service && service.reduceMotion)

    // The playing bars step through their rise and fall at ~8 frames a second, a
    // meter's cadence, instead of animating every display frame: three bars on a
    // 90 Hz panel kept the whole bar repainting for as long as music played.
    readonly property int barStepMs: 125
    property int barTick: 0
    Timer {
        interval: root.barStepMs
        repeat: true
        running: root.showBars && root.canAnimate
        onTriggered: root.barTick = (root.barTick + 1) % 1200
    }
    // the old keyframes (rise, fall, rise, settle over 1.5 s, each bar 140 ms
    // behind the previous one) sampled with the same in-out sine ease
    function barHeightAt(index, ms) {
        const keys = [4, index === 1 ? 11 : 8, 3, index === 2 ? 9 : 6, 4];
        const spans = [380, 420, 360, 340];
        let t = ((ms - index * 140) % 1500 + 1500) % 1500;
        for (let k = 0; k < spans.length; k++) {
            if (t <= spans[k]) {
                const e = (1 - Math.cos(Math.PI * t / spans[k])) / 2;
                return keys[k] + (keys[k + 1] - keys[k]) * e;
            }
            t -= spans[k];
        }
        return keys[0];
    }
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
            id: logo
            objectName: "crateMarkLogo"
            anchors.verticalCenter: parent.verticalCenter
            height: 15 * root.s
            brand: root.tone === "brand"
            color: root.tone === "ink" ? Theme.bright : Theme.accent
            opacity: (area.containsMouse || root.open) ? 1.0 : 0.9
        }

        Text {
            id: wordmark
            visible: root.showLabel && logo.width + row.spacing + implicitWidth
                + (root.showBars ? row.spacing + bars.width : 0) <= root.budget
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
            objectName: "cratePlayingBars"
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
                    height: (root.canAnimate && root.showBars
                        ? root.barHeightAt(bar.index, root.barTick * root.barStepMs)
                        : [5, 10, 7][bar.index]) * root.s
                }
            }
        }

        TrackTicker {
            objectName: "crateTrackViewport"
            textObjectName: "crateTrackText"
            anchors.verticalCenter: parent.verticalCenter
            readonly property real remaining: root.budget
                - logo.width - row.spacing
                - (wordmark.visible ? wordmark.implicitWidth + row.spacing : 0)
                - (bars.visible ? bars.width + row.spacing : 0)
            visible: root.showTrack && remaining > 0
            width: Math.min(implicitWidth, Math.max(0, remaining))
            text: root.trackText
            color: root.playing ? Theme.bright : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 12 * root.s
            playing: root.playing && root.canAnimate
            scaleFactor: root.s
            continuous: true
            elideWhenStill: true
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
