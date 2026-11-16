import QtQuick
import Quickshell.Services.Mpris

// Adapts Crate's MPRIS player (org.mpris.MediaPlayer2.crate) to the plain object NowPlaying
// reads. Loaded only through a Loader gated on the session lock: SDDM never imports this file.
Item {
    id: root

    readonly property var source: {
        var vals = Mpris.players.values;
        for (var i = 0; i < vals.length; i++) {
            var n = String(vals[i].dbusName || "");
            if (n.endsWith(".crate"))
                return vals[i];
        }
        return null;
    }
    readonly property var player: source ? adapter : null

    QtObject {
        id: adapter
        readonly property string title: root.source ? String(root.source.trackTitle || "") : ""
        readonly property string artist: root.source ? String(root.source.trackArtist || "") : ""
        readonly property string artUrl: root.source ? String(root.source.trackArtUrl || "") : ""
        property real position: root.source ? root.source.position : 0
        readonly property real length: root.source ? root.source.length : 0
        readonly property bool playing: root.source ? root.source.playbackState === MprisPlaybackState.Playing : false
    }

    // MprisPlayer.position does not tick on its own; ask for a fresh value while playing.
    Timer {
        interval: 1000
        repeat: true
        running: adapter.playing && !!root.source && root.source.positionSupported
        onTriggered: root.source.positionChanged()
    }
}
