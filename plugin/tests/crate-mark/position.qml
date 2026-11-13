import QtQuick
import Quickshell
import "content" as Crate
import "service" as Service

ShellRoot {
    id: root

    QtObject {
        id: player
        property string dbusName: "org.mpris.MediaPlayer2.crate"
        property int uniqueId: 1
        property real position: 345
        property bool canTogglePlaying: true
        property bool canGoNext: true
        property bool canGoPrevious: true
    }
    QtObject {
        id: service
        property var player: root.peer
        property bool playing: true
        property bool running: true
        property bool stopped: false
        property bool hasTrack: true
        property bool canSeek: true
        property bool controlConnected: false
        property string title: "One song"
        property string bodyFont: ""
        property string artist: ""
        property string album: ""
        property string artUrl: ""
        property real length: 180.955
    }
    Service.Main { id: mprisService }
    Crate.Panel {
        active: true
        pluginApi: QtObject {
            readonly property var mainInstance: mprisService
            readonly property string pluginDir: Quickshell.env("PLUGIN_DIR")
        }
    }
    property var peer: player
    Crate.Panel {
        id: panel
        pluginApi: QtObject {
            readonly property var mainInstance: service
            readonly property string pluginDir: Quickshell.env("PLUGIN_DIR")
        }
        active: false
    }
    function check(value, message) {
        if (!value) throw new Error(message);
    }

    Timer {
        id: schedule
        property int step: 0
        interval: 1250
        triggeredOnStart: true
        running: true
        repeat: true
        onTriggered: {
            try {
                switch (++step) {
                case 1:
                    panel.active = true;
                    break;
                case 2:
                    root.check(panel.pos === 0, "stalled clock advanced");
                    player.dbusName = "org.mpris.MediaPlayer2.other";
                    player.uniqueId++;
                    break;
                case 3:
                    root.check(panel.pos === service.length, "new track not clamped to duration");
                    service.playing = false;
                    player.dbusName = "org.mpris.MediaPlayer2.paused";
                    player.uniqueId++;
                    break;
                case 4:
                    root.check(panel.pos === 42.25, "paused raw position not read");
                    console.log("CRATE-MARK-SIMULATE-SEEK");
                    break;
                case 5:
                    player.positionChanged();
                    break;
                case 6:
                    root.check(panel.pos === 77.5, "paused seek not read");
                    panel.active = false;
                    break;
                case 7:
                    root.check(panel.pos === 0, "closed panel kept its old position");
                    root.check(mprisService.running && mprisService.hasTrack && mprisService.canSeek
                        && mprisService.controlConnected && mprisService.playing && mprisService.title === "Fixture song",
                        "real MPRIS player failed to attach");
                    console.log("CRATE-MARK-QUIT-PLAYER");
                    break;
                case 8:
                    root.check(!mprisService.running && !mprisService.hasTrack && !mprisService.canSeek
                        && !mprisService.playing && mprisService.stopped
                        && mprisService.length === 0 && mprisService.title === "",
                        "service retained player state after Crate quit");
                    mprisService.seekTo(10);
                    console.log("CRATE-MARK-POSITION-PASS");
                    Qt.quit();
                }
            } catch (err) {
                console.error(err);
                Qt.quit();
            }
        }
    }
}
