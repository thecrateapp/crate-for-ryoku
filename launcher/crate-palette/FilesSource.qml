import QtQuick
import Quickshell
import Quickshell.Io

// Files under $HOME whose name holds the text: fd, from three characters, debounced.
QtObject {
    id: source

    property string text: ""
    property int limit: 6
    property var rows: []

    property string asked: ""
    property var lines: []

    function reset() {
        debounce.stop();
        source.rows = [];
    }

    onTextChanged: {
        const t = source.text.trim();
        if (t.length < 3) {
            debounce.stop();
            source.rows = [];
            return;
        }
        debounce.restart();
    }

    property Timer debounce: Timer {
        interval: 150
        onTriggered: {
            if (finder.running)
                finder.running = false;
            source.asked = source.text.trim();
            source.lines = [];
            finder.command = ["fd", "--type", "f", "--fixed-strings", "--ignore-case",
                "--max-results", String(source.limit), "--absolute-path", "--", source.asked,
                Quickshell.env("HOME")];
            finder.running = true;
        }
    }

    property Process finder: Process {
        stdout: SplitParser {
            onRead: data => source.lines = source.lines.concat([data])
        }
        onExited: {
            // an answer for an older text is dropped
            if (source.asked !== source.text.trim())
                return;
            source.rows = source.lines.filter(p => p.charAt(0) === "/").map(p => {
                const cut = p.lastIndexOf("/");
                return { kind: "file", title: p.slice(cut + 1), subtitle: p.slice(0, cut), path: p };
            });
        }
    }
}
