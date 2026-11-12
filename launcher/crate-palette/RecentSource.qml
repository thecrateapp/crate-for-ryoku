import QtQuick
import Quickshell
import Quickshell.Io
import "lib/recent.js" as Recent

// Recently used local files (freedesktop recently-used.xbel), newest first.
QtObject {
    id: source

    property string text: ""
    property int limit: 5
    property var all: []

    readonly property var rows: Recent.filterRecent(source.all, source.text, source.limit)

    function reset() {
        source.text = "";
        xbel.reload();
    }

    property FileView xbel: FileView {
        path: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/recently-used.xbel"
        printErrors: false
        onLoaded: source.all = Recent.parseXbel(text())
        onLoadFailed: source.all = []
    }
}
