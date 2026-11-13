pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// The plugin's logic, no UI.
//  - Is Crate installed? (its desktop entry) The bar mark only shows when it is.
//  - Now playing and transport: the Crate player on MPRIS
//    (org.mpris.MediaPlayer2.crate).
//  - Volume, shuffle, repeat and the equalizer: Crate's local control socket
//    ($XDG_RUNTIME_DIR/crate/control.sock, Crate 3.4+), one JSON object per
//    line. Older Crate builds have no socket; the panel then shows now playing
//    and transport only.
// The service connects to the socket only
// while Crate's player is on the bus.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property string appId: (settings && settings.appId) ? String(settings.appId) : "app.cratemusic.crate.desktop"

    // ---- Crate's body font, loaded once for the panel (it is created per open)
    FontLoader { id: roboto; source: Qt.resolvedUrl("../content/fonts/roboto-latin.woff2") }
    FontLoader { source: Qt.resolvedUrl("../content/fonts/roboto-latin-ext.woff2") }
    readonly property string bodyFont: roboto.status === FontLoader.Ready ? roboto.name : ""

    // ---- installation: the desktop entry, re-resolved on install/removal
    // The packaged entry is "Crate"; the app registers its own id at first run.
    readonly property var entryIds: [svc.appId, "app.cratemusic.crate.desktop", "Crate", "crate-desktop"]
    property var entry: null
    readonly property bool appInstalled: svc.entry !== null
    readonly property bool installed: svc.appInstalled || svc.running

    function resolve() {
        for (var i = 0; i < svc.entryIds.length; i++) {
            var e = DesktopEntries.byId(svc.entryIds[i]);
            if (e) {
                svc.entry = e;
                return;
            }
        }
        svc.entry = null;
    }

    // ---- the Crate player on MPRIS
    function isCrate(p) {
        if (!p)
            return false;
        var n = String(p.dbusName || "");
        return n === "org.mpris.MediaPlayer2.crate"
            || n.indexOf("org.mpris.MediaPlayer2.crate.") === 0
            || String(p.identity || "") === "Crate";
    }

    readonly property var player: {
        var vals = Mpris.players.values;
        for (var i = 0; i < vals.length; i++)
            if (svc.isCrate(vals[i]))
                return vals[i];
        return null;
    }

    readonly property bool running: !!svc.player
    readonly property string title: svc.player?.trackTitle || ""
    readonly property bool hasTrack: svc.title !== ""
    readonly property bool playing: svc.player?.playbackState === MprisPlaybackState.Playing
    readonly property bool stopped: !svc.player || svc.player.playbackState === MprisPlaybackState.Stopped
    readonly property bool reduceMotion: typeof Qt.ReducedMotion !== "undefined"
        && Qt.styleHints.accessibility?.motionPreference === Qt.ReducedMotion
    readonly property string artist: svc.hasTrack ? (svc.player?.trackArtist || "") : ""
    readonly property string album: svc.hasTrack ? (svc.player?.trackAlbum || "") : ""
    readonly property string artUrl: svc.hasTrack ? String(svc.player?.trackArtUrl || "") : ""
    readonly property real length: svc.hasTrack && svc.player?.lengthSupported ? svc.player.length : 0
    readonly property bool canSeek: !!svc.player && svc.hasTrack && svc.length > 0
        && (svc.controlConnected || (svc.player.canSeek && svc.player.positionSupported))

    function togglePlaying() {
        if (svc.player && svc.player.canTogglePlaying)
            svc.player.togglePlaying();
    }
    function next() {
        if (svc.player && svc.player.canGoNext)
            svc.player.next();
    }
    function previous() {
        if (svc.player && svc.player.canGoPrevious)
            svc.player.previous();
    }
    function seekTo(seconds) {
        if (!svc.player || !svc.canSeek)
            return;
        var s = Math.max(0, Math.min(svc.length, seconds));
        if (svc.controlConnected)
            svc.send({ cmd: "seek", position: s });
        else
            svc.player.position = s;
    }

    // "Open Crate": bring the running app forward, or start it.
    function launch() {
        if (svc.controlConnected) {
            svc.send({ cmd: "show" });
            return;
        }
        if (svc.player && svc.player.canRaise) {
            svc.player.raise();
            return;
        }
        svc.resolve();
        if (svc.entry)
            svc.entry.execute();
    }

    // ---- the control socket
    readonly property string socketPath: {
        var runtime = Quickshell.env("XDG_RUNTIME_DIR");
        return runtime ? runtime + "/crate/control.sock" : "";
    }
    // the last {"type":"state"} line: {player:{volume,shuffle,repeat}, eq:{...}}
    property var control: null
    readonly property bool controlConnected: sock.connected && svc.control !== null

    function send(command) {
        if (!sock.connected)
            return;
        sock.write(JSON.stringify(command) + "\n");
        sock.flush();
    }
    function onLine(line) {
        var msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (msg && msg.type === "state" && msg.protocol === 1 && msg.player && msg.eq)
            svc.control = msg;
    }

    function setVolume(v) { svc.send({ cmd: "set_volume", volume: Math.max(0, Math.min(1, v)) }); }
    function setShuffle(on) { svc.send({ cmd: "set_shuffle", on: !!on }); }
    function setRepeat(mode) { svc.send({ cmd: "set_repeat", mode: mode }); }
    function eqEnabled(on) { svc.send({ cmd: "eq_enabled", on: !!on }); }
    function eqMode(mode) { svc.send({ cmd: "eq_mode", mode: mode }); }
    function eqPreset(preset) { svc.send({ cmd: "eq_preset", preset: preset }); }
    function eqGains(gains) { svc.send({ cmd: "eq_gains", gains: gains }); }

    Socket {
        id: sock
        path: svc.socketPath
        connected: false
        parser: SplitParser {
            onRead: data => svc.onLine(data)
        }
        onConnectedChanged: if (!connected) svc.control = null
    }

    // Connect while Crate's player is on the bus; retry while it is not served
    // (Crate starting, or an older Crate without the socket).
    function syncSocket() {
        if (!svc.running || svc.socketPath === "") {
            sock.connected = false;
            svc.control = null;
        } else if (!sock.connected) {
            sock.connected = true;
        }
    }
    onRunningChanged: svc.syncSocket()
    Timer {
        interval: 5000
        repeat: true
        running: svc.running && !sock.connected
        onTriggered: svc.syncSocket()
    }

    onAppIdChanged: svc.resolve()
    Component.onCompleted: {
        svc.resolve();
        svc.syncSocket();
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { svc.resolve(); }
    }
}
