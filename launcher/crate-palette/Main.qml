import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services
import Ryoku.Ui.Singletons
import "lib/palette.js" as Palette

// Crate Palette: a command palette for Ryoku that searches apps, files, recent
// files and the Crate library. A normal search lists the local results first and
// then Crate's best artist, album and track; "cr " (or Tab to CRATE) searches
// Crate alone. The shell's launcher host drives it through show(), hide() and
// shown; apps start through the shell's AppLaunch.
Scope {
    id: root

    // ── the contract the shell's launcher host drives ───────────────────
    property bool openRequested: false
    readonly property bool shown: root.openRequested
    property string monitor: ""

    function show(mon) {
        root.monitor = mon || "";
        root.query = "";
        root.tab = "all";
        root.selected = 0;
        apps.reset();
        files.reset();
        recent.reset();
        crate.reset();
        root.openRequested = true;
    }
    function hide() {
        root.openRequested = false;
    }
    function toggle(mon) {
        root.openRequested ? root.hide() : root.show(mon);
    }
    function stateDump() {
        return { open: root.openRequested, query: root.query, mode: root.mode, tab: root.tab,
            selected: root.selected, count: root.flat.length };
    }

    // ── state ───────────────────────────────────────────────────────────
    property string query: ""
    property string tab: "all"
    property int selected: 0

    readonly property string mode: root.tab === "crate" ? "crate" : "all"
    readonly property string text: root.query.trim()
    readonly property bool blank: root.text.length === 0

    AppsSource {
        id: apps
        text: root.text
        limit: root.tab === "apps" ? 12 : 6
    }
    FilesSource {
        id: files
        text: root.mode === "crate" ? "" : root.text
        limit: root.tab === "files" ? 12 : 4
    }
    RecentSource {
        id: recent
        text: root.text
        limit: root.tab === "rec" ? 12 : 4
    }
    CrateSource {
        id: crate
        active: root.shown
        text: root.text
    }

    // an empty search shows recent files (or every app on the APPS tab)
    readonly property var groups: Palette.merge({
        apps: root.blank && root.tab !== "apps" ? [] : apps.rows,
        files: files.rows,
        recent: recent.rows,
        crate: crate.rows
    }, root.mode, root.tab)
    readonly property var flat: Palette.flatten(root.groups)
    readonly property var offsets: {
        const out = [];
        let n = 0;
        for (let i = 0; i < root.groups.length; i++) {
            out.push(n);
            n += root.groups[i].rows.length;
        }
        return out;
    }
    readonly property var current: root.selected >= 0 && root.selected < root.flat.length ? root.flat[root.selected] : null
    readonly property bool crateSearching: root.mode === "crate" && crate.available && crate.rows.length === 0
    readonly property bool currentIsCrate: !!root.current && ["artist", "album", "track"].indexOf(root.current.kind) >= 0

    readonly property var hints: {
        const out = [];
        if (root.currentIsCrate) {
            out.push("↵ " + I18n.tr("play"));
            if (crate.canQueue)
                out.push("⌥↵ " + I18n.tr("queue"));
            out.push("⇧↵ " + I18n.tr("open in Crate"));
        } else {
            out.push("↵ " + I18n.tr("open"));
        }
        out.push("⇥ " + I18n.tr("mode"));
        return out;
    }
    readonly property string tally: root.mode === "crate" ? I18n.tr("Crate · library").toUpperCase()
        : root.flat.length + " " + I18n.tr(root.flat.length === 1 ? "result" : "results").toUpperCase()

    onFlatChanged: if (root.selected >= root.flat.length) root.selected = Math.max(0, root.flat.length - 1)

    function setTab(id) {
        root.tab = id;
        root.selected = 0;
    }

    // The field's text after an edit: "cr " becomes the CRATE tab.
    function edited(t) {
        if (/^\s*cr\s/i.test(t)) {
            t = Palette.parseQuery(t).text;
            root.tab = "crate";
        }
        root.query = t;
        root.selected = 0;
        return t;
    }

    function key(event, fieldText) {
        const alt = (event.modifiers & Qt.AltModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        switch (event.key) {
        case Qt.Key_Escape:
            root.hide();
            return true;
        case Qt.Key_Down:
        case Qt.Key_Right:
            if (event.key === Qt.Key_Right && root.current && root.current.kind !== "album")
                return false;
            root.selected = Math.min(root.flat.length - 1, root.selected + 1);
            return true;
        case Qt.Key_Up:
        case Qt.Key_Left:
            if (event.key === Qt.Key_Left && root.current && root.current.kind !== "album")
                return false;
            root.selected = Math.max(0, root.selected - 1);
            return true;
        case Qt.Key_Tab:
            root.setTab(Palette.nextTab(root.tab));
            return true;
        case Qt.Key_Backspace:
            if (fieldText.length === 0 && root.tab !== "all") {
                root.setTab("all");
                return true;
            }
            return false;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.run(root.current, alt ? "queue" : shift ? "show" : "");
            return true;
        }
        return false;
    }

    function run(row, how) {
        if (!row)
            return;
        switch (row.kind) {
        case "app":
            root.hide();
            AppLaunch.run(row.entry, null);
            return;
        case "file":
        case "recent":
            root.hide();
            Quickshell.execDetached(["xdg-open", row.path]);
            return;
        case "notice":
            root.hide();
            crate.act("play_item", row);
            return;
        case "artist":
        case "album":
        case "track":
            if (how === "queue" && !crate.canQueue)
                return;
            crate.act(how === "queue" ? "queue_item" : how === "show" ? "show" : "play_item", row);
            root.hide();
            return;
        }
    }

    // the output the host named, else the focused one, else the first
    readonly property var output: {
        const screens = Quickshell.screens;
        const wanted = root.monitor.length > 0 ? root.monitor : Wm.focusedOutput;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === wanted)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    LazyLoader {
        active: root.shown && root.output !== null

        PanelWindow {
            screen: root.output
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "launcher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.hide()
            }

            Card {
                id: palette
                host: root
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 0.18)
                height: implicitHeight
                Component.onCompleted: palette.focusField()
            }
        }
    }
}
