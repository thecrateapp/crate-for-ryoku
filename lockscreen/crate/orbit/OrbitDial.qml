import QtQuick
import QtQuick.Shapes
import "../common"

// Two concentric rings around the hour: minutes inside, seconds outside. Both turn continuously
// from real time so the current minute and second pass the three o'clock pointer, where they are
// spotlit in cyan-hi. The host places the dial so its left part bleeds off the screen.
//
// Cost: one FrameAnimation samples the clock while live; per frame only the two ring rotations
// (and, during a windup, the spin and the streak layer) change. Ticks and labels are built once
// and never move inside their ring; the spotlight is one label per ring that steps once a second.
Item {
    id: root
    objectName: "orbitDial"
    // Design pixels scale per skin instance: the host binds this to its own height / 1200.
    property real uiScale: 1
    // Production samples the clock every frame; tests and the preview pin `now` (live false).
    property bool live: true
    property date now: new Date()
    property bool reduceMotion: CratePalette.reduceMotion
    // 0 to 1, set by the host while PAM works or the reveal plays: how fast the rings spin.
    property real windupProgress: 0
    // While true the spin accumulates (windup, reveal); a settle animates it back instead.
    property bool accelerating: false
    readonly property real minuteRadius: Math.round(CratePalette.s(320, uiScale))
    readonly property real secondRadius: width / 2

    readonly property int tickCount: 60
    readonly property int secondTickCount: 60
    // Extra turn of the minute ring from the windup, in degrees; the seconds ring turns twice as
    // far. A whole number of turns leaves both rings on real time again.
    property real spin: 0
    // Degrees per second of minute-ring spin at full windup (the seconds ring does twice that).
    readonly property real maxSpin: 720

    // Sampled every frame while live; otherwise the pinned `now`, which ticks once a second.
    readonly property bool driving: live && !reduceMotion
    property real frameMs: Date.now()
    onDrivingChanged: if (driving) frameMs = Date.now()
    readonly property real timeMs: driving ? frameMs : now.getTime()
    // Local milliseconds into the hour (a Date, so the time zone offset is the local one). Under
    // reduced motion the rings stand on the whole second.
    readonly property real msOfHour: {
        var d = new Date(timeMs);
        var ms = d.getMinutes() * 60000 + d.getSeconds() * 1000 + d.getMilliseconds();
        return reduceMotion ? Math.floor(ms / 1000) * 1000 : ms;
    }
    readonly property int currentSecond: Math.floor((msOfHour % 60000) / 1000)
    readonly property int currentMinute: Math.floor(msOfHour / 60000)
    // Minute m sits m * 6 degrees clockwise from three o'clock: turning back by the elapsed
    // fraction of the hour brings the current instant to three o'clock (multiply first: exact).
    readonly property real targetRotation: -(msOfHour * 360 / 3600000)
    readonly property real secondTargetRotation: -((msOfHour % 60000) * 360 / 60000)
    readonly property real ringRotation: minuteRing.rotation
    readonly property real secondRotation: secondRing.rotation

    FrameAnimation {
        running: root.driving || root.accelerating
        onTriggered: {
            if (root.driving) root.frameMs = Date.now();
            if (root.accelerating && root.windupProgress > 0)
                root.spin += frameTime * root.maxSpin * root.windupProgress;
        }
    }

    // Spin back onto real time: forward to the next whole turn, decelerating from the current
    // speed; a windup that never got going unwinds the few degrees it turned.
    property int settleDuration: 0
    function settle() {
        settleAnim.stop();
        var v = maxSpin * windupProgress, from = spin, to;
        if (v < 90 && spin - Math.floor(spin / 360) * 360 < 45) {
            to = Math.floor(spin / 360) * 360;
            settleDuration = 300;
        } else {
            to = Math.ceil(spin / 360) * 360;
            // OutCubic starts at 3 * distance / duration: add turns until that is not faster than now.
            while (3 * (to - from) / Math.max(v, 1) < 0.35) to += 360;
            settleDuration = Math.round(Math.min(1200, Math.max(350, 3000 * (to - from) / Math.max(v, 1))));
        }
        settleAnim.from = from;
        settleAnim.to = to;
        settleAnim.duration = settleDuration;
        settleAnim.start();
    }
    function stopSettle() { settleAnim.stop(); }
    function reset() { settleAnim.stop(); spin = 0; }
    NumberAnimation {
        id: settleAnim
        target: root; property: "spin"; easing.type: Easing.OutCubic
        onFinished: root.spin = 0
    }

    height: width

    // The readout: a window at three o'clock between the two rings, holding the current minute
    // and second as fixed text. The rings turn past it with their own spotlight; the readout
    // never drifts with them.
    Rectangle {
        id: readout
        objectName: "orbitPointer"
        readonly property real gap: Math.round(CratePalette.s(12, root.uiScale))
        x: root.width / 2 + root.minuteRadius + gap
        // Clear of the minute ticks (inside the inner ring) and of the seconds numbers (s(42)
        // inside the outer ring).
        width: Math.max(0, root.secondRadius - root.minuteRadius - gap - Math.round(CratePalette.s(56, root.uiScale)))
        height: Math.round(CratePalette.s(40, root.uiScale))
        y: root.height / 2 - height / 2
        radius: CratePalette.radius
        color: Qt.rgba(10 / 255, 10 / 255, 15 / 255, 0.62)
        border.width: 1
        // Active while the rings wind up: the window warms to cyan with them.
        border.color: Qt.tint(CratePalette.hairline, Qt.rgba(6 / 255, 182 / 255, 212 / 255, Math.min(0.8, root.windupProgress)))
        readonly property real px: Math.round(CratePalette.s(16, root.uiScale))
        Text {
            objectName: "minuteReadout"
            anchors { verticalCenter: parent.verticalCenter; right: divider.left; rightMargin: readout.gap }
            text: (root.currentMinute < 10 ? "0" : "") + root.currentMinute
            color: CratePalette.cyanHi
            font.family: CratePalette.monoFamily
            font.pixelSize: readout.px
            font.letterSpacing: readout.px * 0.12
        }
        Rectangle {
            id: divider
            anchors.centerIn: parent
            width: 1
            height: Math.round(parent.height * 0.45)
            color: CratePalette.hairline
        }
        Text {
            objectName: "secondReadout"
            anchors { verticalCenter: parent.verticalCenter; left: divider.right; leftMargin: readout.gap }
            text: (root.currentSecond < 10 ? "0" : "") + root.currentSecond
            color: CratePalette.secondary
            font.family: CratePalette.monoFamily
            font.pixelSize: readout.px
            font.letterSpacing: readout.px * 0.12
        }
    }

    // Cyan streaks trail the rings while they wind up: fixed arcs on their own layer, which
    // only turns and fades (no geometry changes per frame).
    Item {
        id: streaks
        objectName: "orbitStreaks"
        anchors.fill: parent
        opacity: Math.min(1, root.windupProgress * 1.6)
        visible: opacity > 0
        rotation: -root.spin * 2.6
        Repeater {
            model: 9
            delegate: Shape {
                id: streak
                required property int index
                // Spread over and between the rings; a fixed pseudo-random layout.
                readonly property real r: root.minuteRadius + (root.secondRadius - root.minuteRadius) * ((index * 0.37) % 1.0)
                    + Math.round(CratePalette.s(index % 3 === 0 ? 36 : 0, root.uiScale))
                readonly property real start: (index * 97) % 360
                readonly property real sweep: 28 + (index * 13) % 36
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // Head bright and short, tail long and faint; the ring turns counterclockwise so
                // the tail follows clockwise of the head.
                ShapePath {
                    strokeColor: Qt.rgba(6 / 255, 182 / 255, 212 / 255, 0.18)
                    strokeWidth: Math.max(1, Math.round(CratePalette.s(2, root.uiScale)))
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: streak.r; radiusY: streak.r
                        startAngle: streak.start; sweepAngle: streak.sweep }
                }
                ShapePath {
                    strokeColor: Qt.rgba(6 / 255, 182 / 255, 212 / 255, 0.5)
                    strokeWidth: Math.max(1, Math.round(CratePalette.s(2, root.uiScale)))
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: streak.r; radiusY: streak.r
                        startAngle: streak.start; sweepAngle: streak.sweep * 0.45 }
                }
                ShapePath {
                    strokeColor: CratePalette.cyanHi
                    strokeWidth: Math.max(1.5, CratePalette.s(2.5, root.uiScale))
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: streak.r; radiusY: streak.r
                        startAngle: streak.start; sweepAngle: Math.max(2, streak.sweep * 0.12) }
                }
            }
        }
    }

    // Ring hairline: neutral at rest, warming to cyan as the rings wind up.
    readonly property color ringLine: Qt.tint(CratePalette.hairline, Qt.rgba(6 / 255, 182 / 255, 212 / 255, Math.min(0.55, root.windupProgress * 0.7)))

    component Ring: Item {
        id: ring
        // Ring radius, tick lengths (current, major, minor) and the label radius/size.
        property real r
        property int current: 0
        property string tickPrefix
        property string labelPrefix
        property string spotName
        property real currentLen
        property real majorLen
        property real minorLen
        property real labelInset
        property real labelPx
        x: root.width / 2 - r
        y: root.height / 2 - r
        width: r * 2
        height: width

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: root.ringLine
        }
        Repeater {
            model: 60
            delegate: Item {
                id: tickSlot
                required property int index
                readonly property bool current: index === ring.current
                readonly property bool major: index % 5 === 0
                x: ring.r; y: ring.r
                width: 0; height: 0
                rotation: index * 6
                Rectangle {
                    objectName: ring.tickPrefix + tickSlot.index
                    readonly property real len: tickSlot.current ? ring.currentLen : tickSlot.major ? ring.majorLen : ring.minorLen
                    x: ring.r - len
                    height: tickSlot.current ? Math.max(2, Math.round(CratePalette.s(3, root.uiScale))) : tickSlot.major ? 2 : 1
                    y: -height / 2
                    width: len
                    antialiasing: true
                    color: tickSlot.current ? CratePalette.cyanHi : tickSlot.major ? CratePalette.secondary : CratePalette.faint
                }
            }
        }
        // Mono numbers every five, radial so the one at the pointer reads level.
        Repeater {
            model: 12
            delegate: Item {
                id: numSlot
                required property int index
                readonly property int value: index * 5
                x: ring.r; y: ring.r
                width: 0; height: 0
                rotation: value * 6
                Text {
                    objectName: ring.labelPrefix + numSlot.value
                    // The spotlight draws the current one.
                    visible: numSlot.value !== ring.current
                    text: (numSlot.value < 10 ? "0" : "") + numSlot.value
                    color: CratePalette.faint
                    font.family: CratePalette.monoFamily
                    font.pixelSize: ring.labelPx
                    font.letterSpacing: ring.labelPx * 0.12
                    x: ring.r - ring.labelInset - width / 2
                    y: -height / 2
                }
            }
        }
        // Spotlight: the current value, cyan-hi, on its own slot of the ring.
        Item {
            x: ring.r; y: ring.r
            width: 0; height: 0
            rotation: ring.current * 6
            Text {
                objectName: ring.spotName
                text: (ring.current < 10 ? "0" : "") + ring.current
                color: CratePalette.cyanHi
                font.family: CratePalette.monoFamily
                font.pixelSize: ring.labelPx
                font.letterSpacing: ring.labelPx * 0.12
                x: ring.r - ring.labelInset - width / 2
                y: -height / 2
            }
        }
    }

    Ring {
        id: secondRing
        objectName: "secondRing"
        r: root.secondRadius
        current: root.currentSecond
        rotation: root.secondTargetRotation - root.spin * 2
        tickPrefix: "secondTick"
        labelPrefix: "secondNumber"
        spotName: "secondSpot"
        currentLen: Math.round(CratePalette.s(26, root.uiScale))
        majorLen: Math.round(CratePalette.s(16, root.uiScale))
        minorLen: Math.round(CratePalette.s(8, root.uiScale))
        labelInset: Math.round(CratePalette.s(42, root.uiScale))
        labelPx: Math.round(CratePalette.s(13, root.uiScale))
    }
    Ring {
        id: minuteRing
        objectName: "minuteRing"
        r: root.minuteRadius
        current: root.currentMinute
        rotation: root.targetRotation - root.spin
        tickPrefix: "tick"
        labelPrefix: "dialNumber"
        spotName: "minuteSpot"
        currentLen: Math.round(CratePalette.s(40, root.uiScale))
        majorLen: Math.round(CratePalette.s(24, root.uiScale))
        minorLen: Math.round(CratePalette.s(12, root.uiScale))
        labelInset: Math.round(CratePalette.s(58, root.uiScale))
        labelPx: Math.round(CratePalette.s(15, root.uiScale))
    }
}
