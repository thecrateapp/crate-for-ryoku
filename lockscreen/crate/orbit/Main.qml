import QtQuick
import "../common"
import "../common/i18n"

SkinRoot {
    id: root
    currentUser: userSwitch.currentUser
    focusTarget: passwordField

    // Design geometry at 1920x1200: the rings' centre and radii, in skin pixels. The seconds ring
    // is the outer one and sets the dial's size. On a portrait screen the dial rides higher and
    // the weekday and date stack under it instead of beside it.
    readonly property real secondRadius: Math.round(CratePalette.s(470, root.uiScale))
    readonly property real dialCx: Math.round(CratePalette.s(250, root.uiScale))
    readonly property real dialCy: root.portrait ? Math.round(root.height * 0.4) : root.height / 2
    readonly property real infoX: root.portrait ? root.margin : dialCx + secondRadius + Math.round(CratePalette.s(56, root.uiScale))
    readonly property real infoY: dialCy + secondRadius + Math.round(CratePalette.s(48, root.uiScale))

    // Motion. Enter winds the rings up while PAM works (InQuint, like orbital's windup); a
    // failure settles them back on real time; a success fades and scales the UI out while the
    // lock shell holds the surface (theme.conf unlockRevealMs / unlockSensorRevealMs). None of it
    // runs under reduced motion, where a success is a plain fade.
    readonly property int windupMs: 1600
    readonly property int sensorWindupMs: 900
    readonly property int revealMs: 520
    // "idle" | "windup" | "settling" | "reveal"
    property string motionState: "idle"
    property real windupProgress: 0
    property real revealProgress: 0
    readonly property bool motionAllowed: !root.reduceMotion
    readonly property real dialScale: root.motionAllowed ? 1 + 0.16 * (1 - Math.pow(1 - root.revealProgress, 3)) : 1

    // How long a finished reveal may sit on screen before the UI comes back on its own (the lock
    // shell should have dropped the surface well before; tests shorten it).
    property int revealRestoreMs: sensorWindupMs + revealMs + 4000

    function startWindup(duration) {
        // A security-key PIN is followed by a touch prompt: nothing to wind up for.
        if (!motionAllowed || motionState === "reveal" || keyState === "pin") return;
        // Typing again during a settle: wind up from wherever the rings are now.
        progressSettle.stop();
        settleDone.stop();
        dial.stopSettle();
        motionState = "windup";
        windupAnim.stop();
        windupAnim.from = windupProgress;
        windupAnim.to = 1;
        windupAnim.duration = duration;
        windupAnim.easing.type = Easing.InQuint;
        windupAnim.start();
        windupWatchdog.restart();
    }
    // PAM said no (or never answered): stop pushing and coast back onto real time.
    function settle() {
        windupWatchdog.stop();
        if (motionState !== "windup") return;
        windupAnim.stop();
        motionState = "settling";
        dial.settle();
        progressSettle.from = windupProgress;
        progressSettle.duration = Math.min(dial.settleDuration, 600);
        progressSettle.start();
        settleDone.interval = dial.settleDuration + 20;
        settleDone.restart();
    }
    function reveal() {
        windupWatchdog.stop();
        sensorWindup.stop();
        settleDone.stop();
        progressSettle.stop();
        if (motionAllowed) {
            // The rings whip round as the UI leaves, however quickly PAM answered.
            dial.stopSettle();
            windupAnim.stop();
            windupAnim.from = windupProgress;
            windupAnim.to = 1;
            windupAnim.duration = revealMs;
            windupAnim.easing.type = Easing.OutQuad;
            windupAnim.start();
        }
        motionState = "reveal";
        revealAnim.restart();
        revealRestore.restart();
    }
    // Everything back at rest and visible: the lock surface is (still) up.
    function restore() {
        windupAnim.stop(); progressSettle.stop(); revealAnim.stop();
        windupWatchdog.stop(); sensorWindup.stop(); settleDone.stop(); revealRestore.stop();
        dial.reset();
        windupProgress = 0;
        revealProgress = 0;
        motionState = "idle";
    }

    NumberAnimation { id: windupAnim; target: root; property: "windupProgress" }
    NumberAnimation { id: progressSettle; target: root; property: "windupProgress"; to: 0; easing.type: Easing.OutCubic }
    NumberAnimation { id: revealAnim; target: root; property: "revealProgress"; from: 0; to: 1; duration: root.revealMs }
    Timer {
        id: settleDone
        onTriggered: { root.windupProgress = 0; dial.reset(); root.motionState = "idle"; }
    }
    // A PAM that never answers (a key waiting for a touch) does not keep the rings spinning.
    Timer { id: windupWatchdog; interval: 8000; onTriggered: root.settle() }
    Timer { id: sensorWindup; interval: root.sensorWindupMs; onTriggered: root.reveal() }
    // Still here long after the lock shell should have dropped the surface: the unlock did not
    // happen, so show the lock again.
    Timer { id: revealRestore; interval: root.revealRestoreMs; onTriggered: root.restore() }
    // The key now waits for a touch: the rings stop pushing while it does.
    onKeyStateChanged: if (keyState === "touch") settle()

    Connections {
        target: typeof sddm !== "undefined" && sddm && sddm.loginFailed !== undefined ? sddm : null
        ignoreUnknownSignals: true
        // PAM accepted but the shell could not unlock (unlock.sh failed): it reports loginFailed.
        // Bring the UI back at once so ACCESS DENIED and the field are visible.
        function onLoginFailed() { if (root.motionState === "reveal") root.restore(); else root.settle(); }
        function onKeyTimedOut() { root.settle(); }
        function onLoginSucceeded() {
            // A sensor win arrives with nothing typed: a short windup first, then the reveal.
            if (sddm.fingerprintUnlock === true && root.motionState === "idle" && root.motionAllowed) {
                root.startWindup(root.sensorWindupMs);
                sensorWindup.restart();
            } else {
                root.reveal();
            }
        }
        function onSurfaceRevealed() { root.restore(); }
    }

    Item {
        id: stage
        objectName: "orbitStage"
        anchors.fill: parent
        // Ease in: the rings stay readable while they whip round, then the UI is gone.
        opacity: 1 - root.revealProgress * root.revealProgress

        // The rings and the hour scale out from the dial centre on unlock.
        Item {
            id: dialGroup
            anchors.fill: parent
            transform: Scale { origin.x: root.dialCx; origin.y: root.dialCy; xScale: root.dialScale; yScale: root.dialScale }

            OrbitDial {
                id: dial
                uiScale: root.uiScale
                width: root.secondRadius * 2
                x: root.dialCx - root.secondRadius
                y: root.dialCy - root.secondRadius
                live: root.liveClock
                now: root.now
                reduceMotion: root.reduceMotion
                windupProgress: root.windupProgress
                // Nothing left to see once the reveal is done: stop spinning.
                accelerating: root.motionState === "windup" || (root.motionState === "reveal" && root.revealProgress < 1)
            }

            Text {
                id: hourText
                objectName: "hourText"
                text: root.hourDigits
                color: CratePalette.text
                font.family: CratePalette.displayFamily
                font.weight: 800
                font.pixelSize: Math.round(CratePalette.s(220, root.uiScale))
                font.letterSpacing: -Math.round(CratePalette.s(220, root.uiScale)) * 0.03
                x: root.dialCx - width / 2
                y: root.dialCy - height / 2
            }
            Text {
                objectName: "clockAmPm"
                visible: !root.clock24h
                text: root.marker.toUpperCase()
                color: CratePalette.cyanHi
                font.family: CratePalette.monoFamily
                font.pixelSize: Math.round(CratePalette.s(20, root.uiScale))
                font.letterSpacing: Math.round(CratePalette.s(20, root.uiScale)) * 0.14
                x: root.dialCx - width / 2
                y: hourText.y + hourText.height - Math.round(CratePalette.s(30, root.uiScale))
            }
        }

        // Beside the reading window, which already shows the minute: the weekday over the date,
        // centred on the pointer's axis. Portrait: under the dial, from the left margin.
        Column {
            id: info
            objectName: "orbitInfo"
            x: root.infoX
            y: root.portrait ? root.infoY : root.dialCy - height / 2
            Column {
                id: dateBlock
                objectName: "dateBlock"
                readonly property int maxWidth: root.portrait ? Math.max(0, root.width - 2 * root.margin)
                    : Math.max(0, authColumn.x - root.infoX - Math.round(CratePalette.s(48, root.uiScale)))
                spacing: Math.round(CratePalette.s(6, root.uiScale))
                Text {
                    id: weekday
                    objectName: "dateWeekday"
                    text: root.clockLocale.toString(root.now, "dddd").toUpperCase()
                    color: CratePalette.text
                    font.family: CratePalette.displayFamily
                    font.weight: 800
                    font.pixelSize: Math.round(CratePalette.s(40, root.uiScale))
                    font.letterSpacing: Math.round(CratePalette.s(40, root.uiScale)) * 0.02
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, dateBlock.maxWidth)
                }
                Text {
                    objectName: "dateRest"
                    text: root.clockLocale.toString(root.now, "dd MMM yyyy").toUpperCase()
                    color: CratePalette.secondary
                    font.family: CratePalette.monoFamily
                    font.pixelSize: Math.round(CratePalette.s(16, root.uiScale))
                    font.letterSpacing: Math.round(CratePalette.s(16, root.uiScale)) * 0.14
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, dateBlock.maxWidth)
                    visible: width > 0
                }
            }
        }

        // Top right: power links with hairline rules between them.
        PowerRow {
            id: powerRow
            uiScale: root.uiScale
            anchors { right: parent.right; top: parent.top; rightMargin: root.margin; topMargin: Math.round(CratePalette.s(64, root.uiScale)) }
            onActivated: passwordField.focusField()
        }
        Repeater {
            model: 2
            delegate: Rectangle {
                required property int index
                objectName: "powerSep" + index
                readonly property Item prev: powerRow.children[index]
                x: powerRow.x + prev.x + prev.width + powerRow.spacing / 2 - 0.5
                y: powerRow.y
                width: 1
                height: powerRow.height
                color: CratePalette.hairline
            }
        }

        // One discreet line, bottom left.
        NowPlaying {
            id: nowPlaying
            uiScale: root.uiScale
            compact: true
            player: root.showNowPlaying ? root.nowPlayingPlayer : null
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: root.margin; bottomMargin: root.margin }
            width: Math.max(0, Math.min(Math.round(CratePalette.s(520, root.uiScale)), authColumn.x - root.margin - Math.round(CratePalette.s(48, root.uiScale))))
        }

        // Bottom right, right-aligned: who, the field, Unlock, then what went wrong.
        Column {
            id: authColumn
            objectName: "authColumn"
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: root.margin; bottomMargin: root.margin }
            width: Math.min(Math.round(CratePalette.s(360, root.uiScale)), parent.width - 2 * root.margin)
            spacing: Math.round(CratePalette.s(12, root.uiScale))

            UserSwitch {
                id: userSwitch
                uiScale: root.uiScale
                width: parent.width
                model: root.users
                onActivated: passwordField.focusField()
                label {
                    color: CratePalette.text
                    font.family: CratePalette.monoFamily
                    font.pixelSize: Math.round(CratePalette.s(16, root.uiScale))
                    font.letterSpacing: Math.round(CratePalette.s(16, root.uiScale)) * 0.2
                    horizontalAlignment: Text.AlignRight
                }
            }
            PasswordField {
                id: passwordField
                uiScale: root.uiScale
                width: parent.width
                focus: true
                user: root.user
                sessionIndex: root.sessionIndex
                keyState: root.keyState
                onSubmitted: root.startWindup(root.windupMs)
                // PAM never answered (watchdog, key timeout): the rings stop pushing too.
                onCheckAbandoned: root.settle()
            }
            Binding { target: passwordField.input; property: "horizontalAlignment"; value: TextInput.AlignRight }
            Item {
                id: unlockAction
                objectName: "unlockAction"
                x: parent.width - width
                width: unlockRow.width
                height: unlockLink.implicitHeight
                Row {
                    id: unlockRow
                    spacing: Math.round(CratePalette.s(10, root.uiScale))
                    HoverLink {
                        id: unlockLink
                        objectName: "unlockLink"
                        uiScale: root.uiScale
                        text: I18n.tr("Unlock")
                        interactive: passwordField.text !== "" && passwordField.state !== "checking"
                        opacity: interactive ? 1 : 0.55
                        onActivated: { passwordField.submit(); passwordField.focusField(); }
                    }
                    Rectangle {
                        objectName: "unlockMark"
                        anchors.verticalCenter: unlockLink.verticalCenter
                        anchors.verticalCenterOffset: -Math.round(CratePalette.s(2, root.uiScale))
                        width: Math.round(CratePalette.s(7, root.uiScale)); height: width
                        radius: 1
                        color: CratePalette.cyan
                    }
                }
            }
            Item {
                width: parent.width
                height: denied.implicitHeight
                Text {
                    id: denied
                    objectName: "accessDenied"
                    anchors.right: parent.right
                    visible: passwordField.state === "error"
                    text: I18n.tr("ACCESS DENIED")
                    color: CratePalette.danger
                    font.family: CratePalette.monoFamily
                    font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
                    font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.14
                }
            }
            AuthHint {
                uiScale: root.uiScale
                width: parent.width
                horizontalAlignment: Text.AlignRight
                authState: passwordField.state
                notice: passwordField.notice
                keyState: passwordField.keyState
                fingerprintState: root.fingerprintState
            }
        }
    }
}
