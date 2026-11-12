import QtQuick
import Quickshell
import Quickshell.Io
import "lib/crate.js" as Crate

// Crate's library through the app's control socket. One connection while the
// palette is open; a search per text change, and only the latest answer shows.
QtObject {
    id: source

    property bool active: false
    property string text: ""
    property var rows: []
    property bool available: false
    property bool canQueue: false
    property bool canShow: false

    property var tracker: Crate.newTracker()
    property bool greeted: false
    property int artAttempt: 0

    readonly property var notice: [{
        kind: "notice",
        title: "Crate is not running",
        subtitle: "Press Enter to start it",
        art: "",
        duration: 0,
        ref: null
    }]

    function reset() {
        artTimer.stop();
        source.artAttempt = 0;
        source.rows = [];
        source.tracker = Crate.newTracker();
    }

    function send(line, cmd, query) {
        if (!line.length || !socket.connected)
            return false;
        socket.write(line);
        socket.flush();
        source.tracker = Crate.sent(source.tracker, cmd, query);
        return true;
    }

    function search() {
        const t = source.text.trim();
        if (!t.length) {
            source.rows = [];
            return;
        }
        if (!source.greeted) {
            // not connected (yet): say so, and try again
            source.rows = source.available ? [] : source.notice;
            socket.connected = false;
            socket.connected = source.active;
            return;
        }
        source.send(Crate.searchLine(t), "search", t);
    }

    function act(cmd, row) {
        if (row && row.kind === "notice") {
            Quickshell.execDetached(["crate-desktop"]);
            return;
        }
        if (row && row.ref)
            source.send(Crate.actionLine(cmd, row.ref), cmd, "");
    }

    onTextChanged: {
        artTimer.stop();
        source.artAttempt = 0;
        debounce.restart();
    }

    // covers arrive after the reply that listed them: ask again while any is missing
    function waitForArt() {
        const delay = Crate.artRetryDelay(source.artAttempt);
        if (delay < 0 || !Crate.missingArt(source.rows)) {
            artTimer.stop();
            return;
        }
        artTimer.interval = delay;
        artTimer.restart();
    }

    property Timer artTimer: Timer {
        onTriggered: {
            source.artAttempt += 1;
            source.search();
        }
    }
    onActiveChanged: {
        if (!source.active) {
            source.greeted = false;
            source.available = false;
        }
        socket.connected = source.active;
    }

    property Timer debounce: Timer {
        interval: 120
        onTriggered: source.search()
    }

    property Socket socket: Socket {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/crate/control.sock"
        parser: SplitParser {
            onRead: data => {
                const m = Crate.readMessage(data);
                if (!m)
                    return;
                if (m.type === "hello") {
                    const caps = Crate.capabilities(m);
                    source.canQueue = caps.queue;
                    source.canShow = caps.show;
                    source.available = true;
                    source.greeted = true;
                    source.search();
                } else if (m.type === "ack" || m.type === "error") {
                    source.tracker = Crate.acknowledged(source.tracker, m);
                } else if (m.type === "result" && Crate.accepts(source.tracker, m)) {
                    source.rows = Crate.toRows(m.items);
                    source.waitForArt();
                }
            }
        }
        onConnectionStateChanged: {
            if (!connected) {
                source.greeted = false;
                source.tracker = Crate.newTracker();
            }
        }
        onError: {
            source.available = false;
            source.greeted = false;
            if (source.text.trim().length)
                source.rows = source.notice;
        }
    }
}
