import QtQuick
import Quickshell
import Quickshell.Io
import "lib/palette.js" as Palette

// Desktop apps that match the text, minus the ones hidden in Hub > App Launcher.
QtObject {
    id: source

    property string text: ""
    property int limit: 6
    property var hidden: []

    readonly property var rows: {
        const hide = source.hidden;
        const entries = DesktopEntries.applications.values.filter(
            e => !e.noDisplay && hide.indexOf(e.id) < 0);
        return Palette.rankApps(entries, source.text, source.limit).map(e => ({
            kind: "app",
            title: e.name,
            subtitle: e.genericName || e.comment || "",
            icon: e.icon,
            entry: e
        }));
    }

    // text is bound by the palette; nothing to clear
    function reset() {
    }

    // launcher.json is Settings' file: read it, never write it.
    property FileView config: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/launcher.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text());
                const list = o && Array.isArray(o.hiddenApps) ? o.hiddenApps : [];
                source.hidden = list.filter(x => typeof x === "string");
            } catch (e) {
                source.hidden = [];
            }
        }
        onLoadFailed: source.hidden = []
    }
}
