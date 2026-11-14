import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// The Crate panel, drawn to Crate's own player spec (app/listen, Crate V3
// tokens): the progress beam, the transport and close buttons, the chips and
// the mono labels are the shell kit's own (Beam, IconButton, Chip, TrackLabel,
// re-exported by the plugin kit), so this panel and the kit cannot drift; the
// spectrum play button and the equalizer chart with its Catmull-Rom curve
// stay Crate's. The title runs as an all-caps JetBrains Mono ticker.
// Shuffle, repeat and the equalizer come from Crate's control socket (Crate
// 3.4+); with an older Crate the panel shows now playing and transport. There is
// no volume control: Crate's player volume is not the system volume yet, so a
// slider here would mislead (the bar's own audio panel owns the volume).
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 416
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool running: service ? service.running : false
    readonly property bool hasTrack: service ? service.hasTrack : false
    readonly property bool playing: service ? service.playing : false
    readonly property bool connected: service ? service.controlConnected : false
    readonly property var ctl: (service && service.control) ? service.control : null
    readonly property var eq: ctl ? ctl.eq : null
    readonly property var pl: ctl ? ctl.player : null

    // ---- Crate V3 tokens (app/shared/ui/tokens/themes.css)
    readonly property color textPrimary: "#f1f5f9"
    readonly property color textMuted: "#999ca0"
    readonly property color textSecondary: Qt.rgba(241 / 255, 245 / 255, 249 / 255, 0.78)
    readonly property color textSubtle: "#7e8084"
    readonly property color textFaint: "#4a4c52"
    readonly property color accent: "#06b6d4"
    readonly property color accentHi: "#67e8f9"
    readonly property color canvas: "#0a0a0f"
    readonly property color raised: "#0f1016"
    readonly property color popover: "#111218"
    readonly property color hairline: Qt.rgba(241 / 255, 245 / 255, 249 / 255, 0.10)
    readonly property color hairlineQuiet: Qt.rgba(241 / 255, 245 / 255, 249 / 255, 0.06)
    readonly property color thumb: "#abe2ee"
    readonly property string mono: Theme.mono
    // the kit's icon buttons draw the catalogue's Solar glyph under crate and this
    // font's glyph of the same name otherwise
    readonly property string glyphFont: "Material Symbols Rounded"
    // Roboto is loaded once by the service (service/Main.qml), not per open
    readonly property string body: (service && service.bodyFont) ? service.bodyFont : Theme.font
    function accentA(a) { return Qt.rgba(6 / 255, 182 / 255, 212 / 255, a); }

    // ---- Solar play and pause for the spectrum button, 24-unit grid (Solar Icons
    // Set by 480 Design, CC BY 4.0); the transport glyphs come from the kit catalogue
    readonly property string iconPlay: "M21.4086 9.35258C23.5305 10.5065 23.5305 13.4935 21.4086 14.6474L8.59662 21.6145C6.53435 22.736 4 21.2763 4 18.9671L4 5.0329C4 2.72368 6.53435 1.26402 8.59661 2.38548L21.4086 9.35258Z"
    readonly property string iconPause: "M2 6C2 4.11438 2 3.17157 2.58579 2.58579C3.17157 2 4.11438 2 6 2C7.88562 2 8.82843 2 9.41421 2.58579C10 3.17157 10 4.11438 10 6V18C10 19.8856 10 20.8284 9.41421 21.4142C8.82843 22 7.88562 22 6 22C4.11438 22 3.17157 22 2.58579 21.4142C2 20.8284 2 19.8856 2 18V6Z M14 6C14 4.11438 14 3.17157 14.5858 2.58579C15.1716 2 16.1144 2 18 2C19.8856 2 20.8284 2 21.4142 2.58579C22 3.17157 22 4.11438 22 6V18C22 19.8856 22 20.8284 21.4142 21.4142C20.8284 22 19.8856 22 18 22C16.1144 22 15.1716 22 14.5858 21.4142C14 20.8284 14 19.8856 14 18V6Z"

    readonly property var sourceLabels: ({
        "user_track_preset": "Your track preset",
        "instance_track_preset": "Curator track preset",
        "instance_album_preset": "Curator album preset",
        "genre_taxonomy_preset": "Genre taxonomy",
        "audio_analysis_preset": "Audio analysis",
        "flat": "Flat"
    })
    function presetLabel(key) {
        if (!key || key === "custom")
            return "Custom";
        return String(key).split("_").map(function (w) {
            return w.length ? w[0].toUpperCase() + w.slice(1) : w;
        }).join(" ");
    }
    readonly property string modeReadout: {
        if (!root.eq || !root.eq.enabled)
            return "Off";
        switch (root.eq.mode) {
        case "smart": return "Smart curve";
        case "genre": return "Genre preset";
        case "adaptive": return "Adaptive";
        default: return "Manual · " + root.presetLabel(root.eq.preset);
        }
    }
    readonly property string infoText: {
        if (!root.eq)
            return "";
        if (root.eq.mode === "smart")
            return root.eq.detail || (root.sourceLabels[root.eq.source] ? "Source: " + root.sourceLabels[root.eq.source] : "");
        if (root.eq.mode === "genre")
            return root.eq.detail ? "Genre: " + root.eq.detail : "No genre for this track";
        if (root.eq.mode === "adaptive")
            return "Audio analysis";
        return "Preset: " + root.presetLabel(root.eq.preset);
    }
    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec));
        var m = Math.floor(sec / 60), r = sec % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
    function close() {
        if (root.pluginApi && root.pluginApi.closePanel)
            root.pluginApi.closePanel();
    }

    readonly property real pos: progress.dragging ? progress.preview : clock.seconds
    PositionReader {
        id: clock
        helper: root.pluginApi?.pluginDir ? root.pluginApi.pluginDir + "/bin/read-position" : ""
        playerName: root.service?.player?.dbusName || ""
        trackSerial: root.service?.player?.uniqueId || 0
        playing: root.playing
        watching: root.visible && root.active && root.hasTrack && !root.service.stopped
        duration: root.service?.length || 0
    }
    Connections {
        target: root.service?.player ?? null
        function onPositionChanged() { if (!root.playing && clock.watching) clock.request(); }
    }

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight

    // ================================================================ parts

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: root.hairline
    }

    // Crate's spectrum play button: 36 px, conic rim, dark core, white Solar Bold glyph.
    component PlayButton: Item {
        id: pb
        property bool isPlaying: false
        signal clicked()
        width: 44
        height: 44
        Item {
            id: body
            anchors.centerIn: parent
            width: 36
            height: 36
            scale: pma.pressed ? 0.95 : (pma.containsMouse ? 1.05 : 1)
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            // aura, conic rim, dark core: CSS conic-gradient(from 218deg, #2894ea,
            // #3ac4dc 84deg, #9cdeec 166deg, #06b6d4 248deg, #2894ea)
            Canvas {
                id: rim
                anchors.centerIn: parent
                width: 52
                height: 52
                renderStrategy: Canvas.Cooperative
                property bool lit: pb.isPlaying
                onLitChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var c = 26;
                    var aura = ctx.createRadialGradient(c, c, 16, c, c, 26);
                    aura.addColorStop(0, rim.lit ? "rgba(6,182,212,0.30)" : "rgba(6,182,212,0.22)");
                    aura.addColorStop(1, "rgba(6,182,212,0)");
                    ctx.fillStyle = aura;
                    ctx.fillRect(0, 0, 52, 52);
                    // Qt's conical gradient runs counter-clockwise from 3 o'clock:
                    // start at 90 - 218 deg and mirror the stops
                    var conic = ctx.createConicalGradient(c, c, (90 - 218) * Math.PI / 180);
                    conic.addColorStop(0.0, "#2894ea");
                    conic.addColorStop(0.311, "#06b6d4");
                    conic.addColorStop(0.539, "#9cdeec");
                    conic.addColorStop(0.767, "#3ac4dc");
                    conic.addColorStop(1.0, "#2894ea");
                    ctx.fillStyle = conic;
                    ctx.beginPath();
                    ctx.arc(c, c, 18, 0, 2 * Math.PI);
                    ctx.fill();
                    var core = ctx.createLinearGradient(0, c - 16, 0, c + 16);
                    core.addColorStop(0, "#0f1016");
                    core.addColorStop(1, "#08090d");
                    ctx.fillStyle = core;
                    ctx.beginPath();
                    ctx.arc(c, c, 16, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.strokeStyle = "rgba(241,245,249,0.10)";
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.arc(c, c, 15.5, 0, 2 * Math.PI);
                    ctx.stroke();
                }
            }
            SolarFill {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: pb.isPlaying ? 0 : 1.5
                width: 16
                height: 16
                path: pb.isPlaying ? root.iconPause : root.iconPlay
                color: root.textPrimary
            }
        }
        MouseArea {
            id: pma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    // ================================================================ layout

    Column {
        id: col
        width: root.width
        spacing: 16

        // ---- header: the mark, CRATE, close
        Item {
            width: parent.width
            height: 28
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                CrateLogo {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    color: root.accentHi
                }
                TrackLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Crate"
                    tone: "accent"
                }
            }
            IconButton {
                objectName: "closeButton"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                glyph: "close"
                glyphFont: root.glyphFont
                onClicked: root.close()
            }
        }

        // ---- now playing
        Column {
            width: parent.width
            spacing: 12

            TrackLabel {
                objectName: "stateLabel"
                text: !root.running ? "Crate is not running" : (!root.hasTrack ? "Nothing playing" : (root.playing ? "Now playing" : "Paused"))
                tone: root.playing ? "active" : "subtle"
            }

            Row {
                visible: root.hasTrack
                width: parent.width
                spacing: 12
                Rectangle {
                    id: cover
                    width: 48
                    height: 48
                    radius: 4
                    color: root.raised
                    clip: true
                    CrateLogo {
                        visible: art.status !== Image.Ready
                        anchors.centerIn: parent
                        height: 18
                        color: root.textFaint
                    }
                    Image {
                        id: art
                        anchors.fill: parent
                        source: root.service ? root.service.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: 96
                        sourceSize.height: 96
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - cover.width - 12
                    spacing: 4
                    TrackTicker {
                        width: parent.width
                        height: 18
                        text: root.service ? root.service.title : ""
                        color: root.textPrimary
                        font.family: root.mono
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.letterSpacing: 13 * 0.04
                        font.capitalization: Font.AllUppercase
                        fadeColor: Scheme.base
                        playing: root.playing && root.active && root.visible && !root.service?.reduceMotion
                    }
                    Text {
                        width: parent.width
                        text: !root.service ? "" : [root.service.artist, root.service.album].filter(function (x) { return x; }).join(" · ")
                        color: root.textMuted
                        font.family: root.body
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

            // transport, Crate's order: shuffle, previous, play, next, repeat
            Row {
                visible: root.hasTrack
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                IconButton {
                    objectName: "shuffleButton"
                    visible: root.connected
                    glyph: "shuffle"
                    glyphFont: root.glyphFont
                    on: root.pl ? root.pl.shuffle : false
                    onClicked: root.service.setShuffle(!(root.pl && root.pl.shuffle))
                }
                IconButton {
                    objectName: "previousButton"
                    glyph: "skip_previous"
                    glyphFont: root.glyphFont
                    enabled: root.service && root.service.player ? root.service.player.canGoPrevious : false
                    onClicked: root.service.previous()
                }
                PlayButton {
                    objectName: "playButton"
                    isPlaying: root.playing
                    onClicked: {
                        root.service.togglePlaying();
                        clock.request();
                    }
                }
                IconButton {
                    objectName: "nextButton"
                    glyph: "skip_next"
                    glyphFont: root.glyphFont
                    enabled: root.service && root.service.player ? root.service.player.canGoNext : false
                    onClicked: root.service.next()
                }
                IconButton {
                    objectName: "repeatButton"
                    visible: root.connected
                    glyph: (root.pl && root.pl.repeat === "one") ? "repeat_one" : "repeat"
                    glyphFont: root.glyphFont
                    on: root.pl ? root.pl.repeat !== "off" : false
                    // off -> all -> one -> off, like Crate's button
                    onClicked: root.service.setRepeat(!root.pl || root.pl.repeat === "off" ? "all" : (root.pl.repeat === "all" ? "one" : "off"))
                }
            }

            // progress: time 36 px | 1 px beam | time 36 px, gap 8
            Row {
                visible: root.hasTrack && root.service && root.service.length > 0
                width: parent.width
                spacing: 8
                Text {
                    width: 36
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: root.fmt(root.pos)
                    color: root.textMuted
                    font.family: root.mono
                    font.pixelSize: 12
                }
                Beam {
                    id: progress
                    objectName: "progressBeam"
                    property real preview: 0
                    width: parent.width - 2 * 36 - 16
                    value: (root.service && root.service.length > 0) ? root.pos / root.service.length : 0
                    interactive: root.service ? root.service.canSeek : false
                    onMoved: v => preview = v * root.service.length
                    onCommitted: v => {
                        root.service.seekTo(v * root.service.length);
                        clock.request();
                    }
                }
                Text {
                    width: 36
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.service ? root.fmt(root.service.length) : ""
                    color: root.textMuted
                    font.family: root.mono
                    font.pixelSize: 12
                }
            }
        }

        // ---- equalizer
        Divider { visible: root.connected }
        Item {
            visible: root.connected
            width: parent.width
            height: eqHead.implicitHeight
            Column {
                id: eqHead
                spacing: 4
                TrackLabel { text: "Equalizer"; tone: "accent" }
                Text {
                    text: root.modeReadout
                    color: root.textMuted
                    font.family: root.mono
                    font.pixelSize: 11
                    font.letterSpacing: 11 * 0.025
                    font.capitalization: Font.AllUppercase
                }
            }
            Chip {
                objectName: "eqToggle"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: (root.eq && root.eq.enabled) ? "On" : "Off"
                on: root.eq ? root.eq.enabled : false
                onClicked: root.service.eqEnabled(!(root.eq && root.eq.enabled))
            }
        }

        // the three automatic modes, as Crate's 3-column chip grid
        Grid {
            visible: root.connected
            width: parent.width
            columns: 3
            columnSpacing: 8
            Repeater {
                model: [
                    { key: "smart", label: "Smart" },
                    { key: "genre", label: "Genre" },
                    { key: "adaptive", label: "Adaptive" }
                ]
                Chip {
                    required property var modelData
                    width: (parent.width - 16) / 3
                    text: modelData.label
                    objectName: "eqMode-" + modelData.key
                    on: root.eq ? (root.eq.enabled && root.eq.mode === modelData.key) : false
                    enabled: root.eq ? root.eq.enabled : false
                    onClicked: root.service.eqMode(modelData.key)
                }
            }
        }

        // what the active mode resolved, as Crate's info band
        Rectangle {
            visible: root.connected && root.eq && root.eq.enabled && root.infoText !== ""
            width: parent.width
            height: infoLabel.implicitHeight + 12
            radius: 4
            color: root.accentA(0.10)
            border.width: 1
            border.color: root.accentA(0.30)
            TrackLabel {
                id: infoLabel
                x: 10
                width: parent.width - 20
                anchors.verticalCenter: parent.verticalCenter
                text: root.infoText
                tone: "active"
            }
        }

        // presets: Crate's chips, in one row that scrolls sideways
        Column {
            visible: root.connected
            width: parent.width
            spacing: 8
            TrackLabel { text: "Presets" }
            Flickable {
                id: presetFlick
                width: parent.width
                height: 32
                clip: true
                contentWidth: presetRow.implicitWidth
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                WheelHandler {
                    onWheel: function (w) {
                        var d = w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x;
                        presetFlick.contentX = Math.max(0, Math.min(presetFlick.contentWidth - presetFlick.width, presetFlick.contentX - d));
                    }
                }
                Row {
                    id: presetRow
                    spacing: 8
                    Repeater {
                        model: (root.eq && root.eq.presets) ? root.eq.presets : []
                        Chip {
                            required property var modelData
                            text: root.presetLabel(modelData)
                            on: root.eq ? (root.eq.enabled && root.eq.mode === "manual" && root.eq.preset === modelData) : false
                            enabled: root.eq ? root.eq.enabled : false
                            onClicked: root.service.eqPreset(modelData)
                        }
                    }
                }
            }
        }

        Divider { visible: root.connected }

        // the band chart: dB column + chart, Crate's EqBands
        Item {
            id: chart
            visible: root.connected && root.eq && root.eq.gains && root.eq.gains.length === 10
            width: parent.width
            height: 128 + 12 + 34
            opacity: (root.eq && root.eq.enabled) ? 1 : 0.4
            readonly property bool editable: root.eq ? (root.eq.enabled && root.eq.mode === "manual") : false
            property var editGains: null
            readonly property var gains: chart.editGains ? chart.editGains : (root.eq ? root.eq.gains : [])
            readonly property real plotX: 24
            readonly property real plotW: width - plotX
            readonly property real plotH: 128
            function bx(i) { return chart.plotX + (i + 0.5) / 10 * chart.plotW; }
            function gy(g) { return (12 - g) / 24 * chart.plotH; }
            readonly property string curvePath: {
                var g = chart.gains;
                if (!g || g.length !== 10)
                    return "";
                var pts = [];
                for (var i = 0; i < 10; i++)
                    pts.push([chart.bx(i), chart.gy(g[i])]);
                var d = "M " + pts[0][0] + " " + pts[0][1];
                for (var k = 0; k < 9; k++) {
                    var p0 = pts[Math.max(0, k - 1)], p1 = pts[k], p2 = pts[k + 1], p3 = pts[Math.min(9, k + 2)];
                    var c1x = p1[0] + (p2[0] - p0[0]) / 6, c1y = p1[1] + (p2[1] - p0[1]) / 6;
                    var c2x = p2[0] - (p3[0] - p1[0]) / 6, c2y = p2[1] - (p3[1] - p1[1]) / 6;
                    d += " C " + c1x + " " + c1y + " " + c2x + " " + c2y + " " + p2[0] + " " + p2[1];
                }
                return d;
            }

            // dB labels
            Repeater {
                model: [{ t: "+12", g: 12 }, { t: "+6", g: 6 }, { t: "0 dB", g: 0 }, { t: "−6", g: -6 }, { t: "−12", g: -12 }]
                Text {
                    required property var modelData
                    x: 0
                    y: Math.max(0, Math.min(chart.plotH - implicitHeight, chart.gy(modelData.g) - implicitHeight / 2))
                    text: modelData.t
                    color: root.textSubtle
                    font.family: root.mono
                    font.pixelSize: 10
                }
            }
            // grid: +-6, +-12 hairlines
            Repeater {
                model: [12, 6, -6, -12]
                Rectangle {
                    required property var modelData
                    x: chart.plotX
                    y: Math.round(chart.gy(modelData)) - (modelData === -12 ? 1 : 0)
                    width: chart.plotW
                    height: 1
                    color: root.hairline
                }
            }
            // band separators
            Repeater {
                model: 9
                Rectangle {
                    required property int index
                    x: Math.round(chart.plotX + (index + 1) / 10 * chart.plotW)
                    width: 1
                    height: chart.plotH
                    color: root.hairlineQuiet
                }
            }
            // bars from 0 dB, 3.4 % wide, #67e8f9 .55 -> .08
            Repeater {
                model: 10
                Rectangle {
                    required property int index
                    readonly property real g: chart.gains.length === 10 ? chart.gains[index] : 0
                    width: Math.max(3, chart.plotW * 0.034)
                    x: chart.bx(index) - width / 2
                    y: Math.min(chart.gy(g), chart.gy(0))
                    height: Math.max(1, Math.abs(chart.gy(g) - chart.gy(0)))
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(103 / 255, 232 / 255, 249 / 255, 0.55) }
                        GradientStop { position: 1.0; color: Qt.rgba(103 / 255, 232 / 255, 249 / 255, 0.08) }
                    }
                }
            }
            // 0 dB dashed line, the glow under the curve, then the curve
            Canvas {
                id: curveCanvas
                width: chart.width
                height: chart.plotH
                renderStrategy: Canvas.Cooperative
                property var g: chart.gains
                onGChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var y0 = Math.round(chart.gy(0)) + 0.5;
                    ctx.strokeStyle = String(root.textFaint);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    for (var x = chart.plotX; x < chart.plotX + chart.plotW; x += 6) {
                        ctx.moveTo(x, y0);
                        ctx.lineTo(Math.min(x + 2, chart.plotX + chart.plotW), y0);
                    }
                    ctx.stroke();
                    if (!chart.curvePath)
                        return;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.path = chart.curvePath;
                    ctx.strokeStyle = "rgba(6,182,212,0.15)";
                    ctx.lineWidth = 14;
                    ctx.stroke();
                    ctx.strokeStyle = String(root.accentHi);
                    ctx.lineWidth = 2.25;
                    ctx.stroke();
                }
            }
            // handles
            Repeater {
                model: 10
                Rectangle {
                    required property int index
                    readonly property real g: chart.gains.length === 10 ? chart.gains[index] : 0
                    x: chart.bx(index) - 5
                    y: chart.gy(g) - 5
                    width: 10
                    height: 10
                    radius: 5
                    color: root.canvas
                    border.width: 1.5
                    border.color: root.accentHi
                }
            }
            // values and frequencies under the chart
            Repeater {
                model: 10
                Column {
                    required property int index
                    x: chart.bx(index) - width / 2
                    y: chart.plotH + 12
                    width: chart.plotW / 10
                    spacing: 4
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            var g = chart.gains.length === 10 ? Math.round(chart.gains[index]) : 0;
                            return (g > 0 ? "+" : "") + g;
                        }
                        color: root.textPrimary
                        font.family: root.mono
                        font.pixelSize: 12
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: (root.eq && root.eq.bands) ? root.eq.bands[index] : ""
                        color: root.textSubtle
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 10 * 0.06
                    }
                }
            }
            // drag the bands in Manual (0.5 dB steps)
            MouseArea {
                x: chart.plotX
                width: chart.plotW
                height: chart.plotH
                enabled: chart.editable
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                function edit(mx, my) {
                    var i = Math.max(0, Math.min(9, Math.floor(mx / (chart.plotW / 10))));
                    var g = Math.round((12 - my / chart.plotH * 24) * 2) / 2;
                    var next = (chart.editGains || root.eq.gains).slice();
                    next[i] = Math.max(-12, Math.min(12, g));
                    chart.editGains = next;
                }
                onPressed: function (m) { edit(m.x, m.y); }
                onPositionChanged: function (m) { if (pressed) edit(m.x, m.y); }
                onReleased: {
                    if (chart.editGains)
                        root.service.eqGains(chart.editGains);
                    chart.editGains = null;
                }
            }
        }

        // an older Crate: no control socket yet
        Text {
            visible: root.running && !root.connected
            width: parent.width
            wrapMode: Text.WordWrap
            text: "The equalizer needs Crate 3.4 or newer."
            color: root.textMuted
            font.family: root.body
            font.pixelSize: 12
        }

        Divider {}

        // Crate's outlined action button ("Play artist")
        Rectangle {
            visible: root.service ? (root.service.appInstalled || root.running) : false
            width: parent.width
            height: 40
            radius: 6
            color: openArea.containsMouse ? root.accentA(0.10) : "transparent"
            border.width: 1
            border.color: root.accent
            Behavior on color { ColorAnimation { duration: 150 } }
            Text {
                anchors.centerIn: parent
                text: root.running ? "Open Crate" : "Start Crate"
                color: root.textPrimary
                font.family: root.body
                font.pixelSize: 14
                font.weight: Font.Medium
            }
            MouseArea {
                id: openArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.service.launch();
                    root.close();
                }
            }
        }
    }
}
