import QtQuick
import Quickshell.Io

Item {
    id: reader
    required property string helper
    required property string playerName
    required property int trackSerial
    required property bool playing
    required property bool watching
    required property real duration
    property real sample: 0
    property int requestId: 0

    readonly property real seconds: reader.duration > 0
        ? Math.min(reader.sample, reader.duration) : reader.sample

    function request() {
        ++requestId;
        if (watching && worker.processId)
            worker.write(JSON.stringify([requestId, playerName]) + "\n");
    }

    function reset() {
        sample = 0;
        request();
    }

    onPlayerNameChanged: reset()
    onTrackSerialChanged: reset()
    onWatchingChanged: reset()
    onPlayingChanged: request()

    Process {
        id: worker
        command: [reader.helper]
        running: reader.watching && reader.helper !== "" && reader.playerName !== ""
        stdinEnabled: true
        onStarted: reader.request()
        stdout: SplitParser {
            onRead: line => {
                const [id, value] = JSON.parse(line);
                if (reader.watching && id === reader.requestId && value !== null)
                    reader.sample = Math.max(0, value);
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: reader.watching && reader.playing
        onTriggered: reader.request()
    }
}
