import QtQuick
import Ryoku.PluginKit.Singletons

// The Crate panel, drawn to Crate's own player spec (app/listen, Crate V3
// tokens): 1 px glow beams for progress and volume, the spectrum play button,
// 18 px Solar icons, pill chips, mono labels, the equalizer chart with its
// Catmull-Rom curve. The title runs as an all-caps JetBrains Mono ticker.
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
    // Roboto is loaded once by the service (service/Main.qml), not per open
    readonly property string body: (service && service.bodyFont) ? service.bodyFont : Theme.font
    function accentA(a) { return Qt.rgba(6 / 255, 182 / 255, 212 / 255, a); }

    // ---- Solar paths, 24-unit grid (Solar Icons Set by 480 Design, CC BY 4.0)
    readonly property string iconPrev: "M21.1392 1.80371C22.1058 2.46477 22.75 3.64507 22.75 5.03297V18.9672C22.75 20.3551 22.1058 21.5354 21.1392 22.1965C20.1604 22.8659 18.8652 22.9827 17.7223 22.2447L6.93329 15.2775C5.78297 14.5347 5.25 13.2342 5.25 12.0001C5.25 10.7659 5.78297 9.46544 6.93329 8.72261L17.7223 1.7555C18.8652 1.01747 20.1604 1.13428 21.1392 1.80371ZM20.2924 3.04182C19.7699 2.68448 19.1298 2.63219 18.536 3.0156L7.74702 9.98271C7.11047 10.3938 6.75 11.1637 6.75 12.0001C6.75 12.8364 7.11047 13.6064 7.74701 14.0174L18.536 20.9846C19.1298 21.368 19.7699 21.3157 20.2924 20.9583C20.8271 20.5926 21.25 19.8885 21.25 18.9672V5.03297C21.25 4.11167 20.8271 3.40753 20.2924 3.04182ZM2 4.25008C2.41421 4.25008 2.75 4.58586 2.75 5.00008V19.0001C2.75 19.4143 2.41421 19.7501 2 19.7501C1.58579 19.7501 1.25 19.4143 1.25 19.0001V5.00008C1.25 4.58586 1.58579 4.25008 2 4.25008Z"
    readonly property string iconNext: "M6.27769 1.7555C5.1348 1.01747 3.83955 1.13428 2.86078 1.80371C1.89423 2.46477 1.25 3.64507 1.25 5.03297V18.9672C1.25 20.3551 1.89423 21.5354 2.86078 22.1965C3.83956 22.8659 5.1348 22.9827 6.2777 22.2447L17.0667 15.2775C18.217 14.5347 18.75 13.2342 18.75 12.0001C18.75 10.7659 18.217 9.46544 17.0667 8.72261L6.27769 1.7555ZM2.75 5.03297C2.75 4.11167 3.17287 3.40753 3.70757 3.04182C4.23005 2.68448 4.87022 2.63219 5.46397 3.0156L16.253 9.98271C16.8895 10.3938 17.25 11.1637 17.25 12.0001C17.25 12.8364 16.8895 13.6064 16.253 14.0174L5.46397 20.9846C4.87023 21.368 4.23005 21.3157 3.70758 20.9583C3.17287 20.5926 2.75 19.8885 2.75 18.9672L2.75 5.03297Z M22.75 5.00008C22.75 4.58586 22.4142 4.25008 22 4.25008C21.5858 4.25008 21.25 4.58586 21.25 5.00008V19.0001C21.25 19.4143 21.5858 19.7501 22 19.7501C22.4142 19.7501 22.75 19.4143 22.75 19.0001V5.00008Z"
    readonly property string iconPlay: "M21.4086 9.35258C23.5305 10.5065 23.5305 13.4935 21.4086 14.6474L8.59662 21.6145C6.53435 22.736 4 21.2763 4 18.9671L4 5.0329C4 2.72368 6.53435 1.26402 8.59661 2.38548L21.4086 9.35258Z"
    readonly property string iconPause: "M2 6C2 4.11438 2 3.17157 2.58579 2.58579C3.17157 2 4.11438 2 6 2C7.88562 2 8.82843 2 9.41421 2.58579C10 3.17157 10 4.11438 10 6V18C10 19.8856 10 20.8284 9.41421 21.4142C8.82843 22 7.88562 22 6 22C4.11438 22 3.17157 22 2.58579 21.4142C2 20.8284 2 19.8856 2 18V6Z M14 6C14 4.11438 14 3.17157 14.5858 2.58579C15.1716 2 16.1144 2 18 2C19.8856 2 20.8284 2 21.4142 2.58579C22 3.17157 22 4.11438 22 6V18C22 19.8856 22 20.8284 21.4142 21.4142C20.8284 22 19.8856 22 18 22C16.1144 22 15.1716 22 14.5858 21.4142C14 20.8284 14 19.8856 14 18V6Z"
    readonly property string iconShuffle: "M19.4697 4.46967C19.7626 4.17678 20.2374 4.17678 20.5303 4.46967L22.5303 6.46967C22.8232 6.76256 22.8232 7.23744 22.5303 7.53033L20.5303 9.53033C20.2374 9.82322 19.7626 9.82322 19.4697 9.53033C19.1768 9.23744 19.1768 8.76256 19.4697 8.46967L20.1893 7.75H18.3971C17.5531 7.75 16.9733 7.75082 16.517 7.79516C16.077 7.83793 15.8108 7.91703 15.59 8.04205C15.3692 8.16707 15.1644 8.35464 14.9013 8.70996C14.6286 9.07834 14.3295 9.57518 13.8953 10.2989L11.3722 14.5041C10.9613 15.189 10.6254 15.7488 10.3042 16.1826C9.96851 16.636 9.616 16.9989 9.14905 17.2632C8.6821 17.5276 8.18961 17.6432 7.62807 17.6978C7.09086 17.75 6.438 17.75 5.63936 17.75H2C1.58579 17.75 1.25 17.4142 1.25 17C1.25 16.5858 1.58579 16.25 2 16.25H5.60286C6.44685 16.25 7.02675 16.2492 7.48296 16.2048C7.92299 16.1621 8.18919 16.083 8.41 15.9579C8.63081 15.8329 8.8356 15.6454 9.09867 15.29C9.37141 14.9217 9.67046 14.4248 10.1047 13.7011L12.6278 9.49586C13.0387 8.81102 13.3746 8.25119 13.6958 7.8174C14.0315 7.36397 14.384 7.00113 14.851 6.73675C15.3179 6.47237 15.8104 6.35677 16.3719 6.30219C16.9091 6.24998 17.562 6.24999 18.3606 6.25L20.1893 6.25L19.4697 5.53033C19.1768 5.23744 19.1768 4.76256 19.4697 4.46967ZM7.73131 7.79145C7.53519 7.75328 7.31332 7.75 6.66762 7.75H2C1.58579 7.75 1.25 7.41421 1.25 7C1.25 6.58579 1.58579 6.25 2 6.25H6.66762C6.69223 6.25 6.7165 6.24999 6.74045 6.24999C7.28573 6.24986 7.6618 6.24977 8.01789 6.31908C8.81735 6.47469 9.54442 6.88635 10.0892 7.49182C10.3318 7.76151 10.5252 8.08403 10.8057 8.55169C10.818 8.57222 10.8305 8.59303 10.8431 8.61413C11.0562 8.96931 10.9411 9.43001 10.5859 9.64312C10.2307 9.85623 9.76999 9.74106 9.55688 9.38587C9.22467 8.83219 9.10771 8.64362 8.97408 8.49509C8.64722 8.13181 8.21098 7.88481 7.73131 7.79145ZM13.4141 14.3569C13.7693 14.1438 14.23 14.2589 14.4431 14.6141C14.7753 15.1678 14.8923 15.3564 15.0259 15.5049C15.3528 15.8682 15.789 16.1152 16.2687 16.2086C16.4648 16.2467 16.6867 16.25 17.3324 16.25H20.1893L19.4697 15.5303C19.1768 15.2374 19.1768 14.7626 19.4697 14.4697C19.7626 14.1768 20.2374 14.1768 20.5303 14.4697L22.5303 16.4697C22.8232 16.7626 22.8232 17.2374 22.5303 17.5303L20.5303 19.5303C20.2374 19.8232 19.7626 19.8232 19.4697 19.5303C19.1768 19.2374 19.1768 18.7626 19.4697 18.4697L20.1893 17.75H17.3324C17.3078 17.75 17.2835 17.75 17.2595 17.75C16.7143 17.7501 16.3382 17.7502 15.9821 17.6809C15.1826 17.5253 14.4556 17.1137 13.9108 16.5082C13.6682 16.2385 13.4748 15.916 13.1943 15.4483C13.182 15.4278 13.1695 15.407 13.1569 15.3859C12.9438 15.0307 13.0589 14.57 13.4141 14.3569Z"
    readonly property string iconRepeat: "M8.46967 2.46967C8.76256 2.17678 9.23744 2.17678 9.53033 2.46967L11.5303 4.46967C11.7448 4.68417 11.809 5.00676 11.6929 5.28701C11.5768 5.56727 11.3033 5.75 11 5.75H9C5.54822 5.75 2.75 8.54822 2.75 12C2.75 15.4517 5.54846 18.25 9.00028 18.25H9.5C9.91421 18.25 10.25 18.5858 10.25 19C10.25 19.4142 9.91421 19.75 9.5 19.75H9.00028C4.72011 19.75 1.25 16.2802 1.25 12C1.25 7.71979 4.71979 4.25 9 4.25H9.18934L8.46967 3.53033C8.17678 3.23744 8.17678 2.76256 8.46967 2.46967ZM13.75 5C13.75 4.58579 14.0858 4.25 14.5 4.25H15C19.2802 4.25 22.75 7.71979 22.75 12C22.75 16.2802 19.2802 19.75 15 19.75H14.8107L15.5303 20.4697C15.8232 20.7626 15.8232 21.2374 15.5303 21.5303C15.2374 21.8232 14.7626 21.8232 14.4697 21.5303L12.4697 19.5303C12.2552 19.3158 12.191 18.9932 12.3071 18.713C12.4232 18.4327 12.6967 18.25 13 18.25H15C18.4518 18.25 21.25 15.4518 21.25 12C21.25 8.54822 18.4518 5.75 15 5.75H14.5C14.0858 5.75 13.75 5.41421 13.75 5Z"
    readonly property string iconRepeatOne: "M8.46967 2.46967C8.76256 2.17678 9.23744 2.17678 9.53033 2.46967L11.5303 4.46967C11.7448 4.68417 11.809 5.00676 11.6929 5.28701C11.5768 5.56727 11.3033 5.75 11 5.75H9C5.54822 5.75 2.75 8.54822 2.75 12C2.75 15.4517 5.54846 18.25 9.00028 18.25H9.5C9.91421 18.25 10.25 18.5858 10.25 19C10.25 19.4142 9.91421 19.75 9.5 19.75H9.00028C4.72011 19.75 1.25 16.2802 1.25 12C1.25 7.71979 4.71979 4.25 9 4.25H9.18934L8.46967 3.53033C8.17678 3.23744 8.17678 2.76256 8.46967 2.46967ZM13.75 5C13.75 4.58579 14.0858 4.25 14.5 4.25H15C19.2802 4.25 22.75 7.71979 22.75 12C22.75 16.2802 19.2802 19.75 15 19.75H14.8107L15.5303 20.4697C15.8232 20.7626 15.8232 21.2374 15.5303 21.5303C15.2374 21.8232 14.7626 21.8232 14.4697 21.5303L12.4697 19.5303C12.2552 19.3158 12.191 18.9932 12.3071 18.713C12.4232 18.4327 12.6967 18.25 13 18.25H15C18.4518 18.25 21.25 15.4518 21.25 12C21.25 8.54822 18.4518 5.75 15 5.75H14.5C14.0858 5.75 13.75 5.41421 13.75 5ZM12.287 9.30709C12.5673 9.42318 12.75 9.69665 12.75 10V14C12.75 14.4142 12.4142 14.75 12 14.75C11.5858 14.75 11.25 14.4142 11.25 14V11.8107L11.0303 12.0303C10.7374 12.3232 10.2626 12.3232 9.96967 12.0303C9.67678 11.7374 9.67678 11.2626 9.96967 10.9697L11.4697 9.46967C11.6842 9.25517 12.0068 9.191 12.287 9.30709Z"

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

    // ---- position tick: only while the panel is open and Crate plays
    property real pos: 0
    function tick() {
        if (!root.service)
            return;
        root.service.refreshPosition();
        root.pos = root.service.position();
    }
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible && root.hasTrack && root.playing
        onTriggered: root.tick()
    }
    onHasTrackChanged: root.tick()
    Connections {
        target: root.service
        function onTitleChanged() { root.tick(); }
        function onPlayingChanged() { root.tick(); }
    }

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight

    // ================================================================ parts

    // Crate's mono label: JetBrains Mono 11 px, 0.14em, uppercase
    component MonoLabel: Text {
        property bool accentTone: false
        color: accentTone ? root.accentHi : root.textSubtle
        font.family: root.mono
        font.pixelSize: 11
        font.letterSpacing: 11 * 0.14
        font.capitalization: Font.AllUppercase
    }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: root.hairline
    }

    // Crate's 1 px glow beam (PlayerProgressBeam): hairline track, gradient
    // fill, an 8 px blurred trail, a 4 px dot at the head, and a 6 px hover
    // thumb. value 0..1; moved() while dragging, committed() on release.
    component Beam: Item {
        id: beam
        property real value: 0
        property bool interactive: true
        property bool hovering: area.containsMouse || area.pressed
        signal moved(real v)
        signal committed(real v)
        height: 24
        readonly property real headX: Math.round(width * Math.max(0, Math.min(1, value)))
        readonly property real cy: Math.round(height / 2)

        Rectangle { y: beam.cy; width: beam.width; height: 1; color: root.hairline }
        Item {
            id: trail
            visible: beam.value > 0
            x: 0
            y: beam.cy - 4 + 0.5
            width: beam.headX
            height: 8
            opacity: 0.65
            Rectangle {
                anchors.fill: parent
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.44; color: root.accentA(0.08) }
                    GradientStop { position: 0.82; color: root.accentA(0.28) }
                    GradientStop { position: 1.0; color: "#70d2e5" }
                }
            }
        }
        Rectangle {
            y: beam.cy
            width: beam.headX
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.accentA(0.14) }
                GradientStop { position: 0.5; color: root.accentA(0.56) }
                GradientStop { position: 1.0; color: "#3ac4dc" }
            }
            Behavior on width { enabled: !area.pressed; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        // the head: 4 px #abe2ee dot with Crate's cyan glow as a halo
        Rectangle {
            x: beam.headX - 4
            y: beam.cy - 3.5
            width: 8
            height: 8
            radius: 4
            color: root.accentA(0.22)
            visible: beam.value > 0
        }
        Rectangle {
            id: dot
            x: beam.headX - 2
            y: beam.cy - 1.5
            width: 4
            height: 4
            radius: 2
            color: root.thumb
            opacity: beam.value > 0 ? 0.62 : 0
        }
        Rectangle {
            x: beam.headX - 5
            y: beam.cy - 4.5
            width: 10
            height: 10
            radius: 5
            color: root.accentA(0.14)
            opacity: beam.hovering && beam.interactive ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: root.thumb
                border.width: 1
                border.color: root.accentA(0.80)
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            enabled: beam.interactive
            hoverEnabled: true
            cursorShape: beam.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            function at(x) { return Math.max(0, Math.min(1, x / beam.width)); }
            onPressed: function (m) { beam.moved(at(m.x)); }
            onPositionChanged: function (m) { if (pressed) beam.moved(at(m.x)); }
            onReleased: function (m) { beam.committed(at(m.x)); }
        }
    }

    // Crate's ghost icon button: 44 px, 18 px icon, 78 % ink, #67e8f9 on hover/on.
    component IconButton: Item {
        id: ib
        property string path: ""
        property bool on: false
        property bool enabledState: true
        signal clicked()
        width: 44
        height: 44
        opacity: ib.enabledState ? 1 : 0.5
        SolarFill {
            anchors.centerIn: parent
            width: 18
            height: 18
            evenOdd: true
            path: ib.path
            color: (ib.on || ma.containsMouse) ? root.accentHi : root.textSecondary
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            enabled: ib.enabledState
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
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

    // Crate's FilterChip: pill, 32 px, mono 12, 0.04em; active is solid #67e8f9.
    component Chip: Rectangle {
        id: chip
        property string text: ""
        property bool on: false
        property bool enabledState: true
        signal clicked()
        width: chipText.implicitWidth + 24
        height: 32
        radius: 16
        opacity: chip.enabledState ? 1 : 0.4
        color: chip.on ? root.accentHi : "transparent"
        border.width: 1
        border.color: chip.on ? root.accentHi : (cma.containsMouse ? Qt.rgba(103 / 255, 232 / 255, 249 / 255, 0.40) : root.hairline)
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.text
            color: chip.on ? root.canvas : (cma.containsMouse ? root.textPrimary : root.textSecondary)
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 12 * 0.04
        }
        MouseArea {
            id: cma
            anchors.fill: parent
            hoverEnabled: true
            enabled: chip.enabledState
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
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
                MonoLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Crate"
                    accentTone: true
                }
            }
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                Repeater {
                    model: [45, -45]
                    Rectangle {
                        required property var modelData
                        anchors.centerIn: parent
                        width: 14
                        height: 1.5
                        radius: 0.75
                        rotation: modelData
                        antialiasing: true
                        color: closeArea.containsMouse ? root.accent : root.textMuted
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        // ---- now playing
        Column {
            width: parent.width
            spacing: 12

            MonoLabel {
                text: !root.running ? "Crate is not running" : (!root.hasTrack ? "Nothing playing" : (root.playing ? "Now playing" : "Paused"))
                accentTone: root.playing
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
                    visible: root.connected
                    path: root.iconShuffle
                    on: root.pl ? root.pl.shuffle : false
                    onClicked: root.service.setShuffle(!(root.pl && root.pl.shuffle))
                }
                IconButton {
                    path: root.iconPrev
                    enabledState: root.service && root.service.player ? root.service.player.canGoPrevious : false
                    onClicked: root.service.previous()
                }
                PlayButton {
                    isPlaying: root.playing
                    onClicked: {
                        root.service.togglePlaying();
                        root.tick();
                    }
                }
                IconButton {
                    path: root.iconNext
                    enabledState: root.service && root.service.player ? root.service.player.canGoNext : false
                    onClicked: root.service.next()
                }
                IconButton {
                    visible: root.connected
                    path: (root.pl && root.pl.repeat === "one") ? root.iconRepeatOne : root.iconRepeat
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
                    width: parent.width - 2 * 36 - 16
                    value: (root.service && root.service.length > 0) ? root.pos / root.service.length : 0
                    interactive: root.service ? root.service.canSeek : false
                    onMoved: v => root.pos = v * root.service.length
                    onCommitted: v => {
                        root.pos = v * root.service.length;
                        root.service.seekTo(root.pos);
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
                MonoLabel { text: "Equalizer"; accentTone: true }
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
                    on: root.eq ? (root.eq.enabled && root.eq.mode === modelData.key) : false
                    enabledState: root.eq ? root.eq.enabled : false
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
            MonoLabel {
                id: infoLabel
                x: 10
                width: parent.width - 20
                anchors.verticalCenter: parent.verticalCenter
                text: root.infoText
                accentTone: true
                elide: Text.ElideRight
            }
        }

        // presets: Crate's chips, in one row that scrolls sideways
        Column {
            visible: root.connected
            width: parent.width
            spacing: 8
            MonoLabel { text: "Presets" }
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
                            enabledState: root.eq ? root.eq.enabled : false
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
