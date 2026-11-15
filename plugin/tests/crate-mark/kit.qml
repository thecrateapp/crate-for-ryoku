import QtQuick
import QtTest as Test
import Quickshell
import Ryoku.Ui.Singletons
import "content" as Mark

// The panel on the shell kit, in the crate and the stock look: the progress beam,
// the transport and close buttons, the chips, the equalizer switch and the labels
// are the kit's own (through Ryoku.PluginKit), the seek readout follows the drag,
// the play button toggles without a script error and its glyph sits centred, the
// cover is a record that spins only while it plays, and with the shell's spectrum
// (pluginApi.spectrum) a ring of marks around it asks for the analysis only while
// the panel shows a playing track.
ShellRoot {
    id: scene
    property int closes: 0

    QtObject {
        id: svc
        property bool running: true
        property bool hasTrack: true
        property bool playing: true
        property bool stopped: false
        property bool controlConnected: true
        property bool canSeek: true
        property bool appInstalled: true
        property bool reduceMotion: true
        property real length: 200
        property string title: "Umbral"
        property string artist: "Fixture"
        property string album: "Tests"
        property string artUrl: ""
        property string bodyFont: ""
        property QtObject player: QtObject {
            property bool canGoPrevious: true
            property bool canGoNext: false
            property string dbusName: ""
            property int uniqueId: 0
        }
        property var control: ({
            player: { shuffle: true, repeat: "one" },
            eq: { enabled: true, mode: "smart", preset: "flat", presets: ["flat", "rock"],
                  gains: [0, 1, 2, 3, 2, 1, 0, -1, -2, -1], source: "flat", detail: "" }
        })
        property int toggles: 0
        property real seeked: -1
        property var modes: []
        function togglePlaying() { ++toggles }
        function seekTo(t) { seeked = t }
        function eqMode(k) { modes = modes.concat([k]) }
        property var eqSet: undefined
        function eqEnabled(on) { eqSet = on }
        function eqPreset(p) {}
        function eqGains(g) {}
        function setShuffle(on) {}
        function setRepeat(r) {}
        function previous() {}
        function next() {}
        function launch() {}
    }
    QtObject {
        id: api
        property var pluginSettings: ({})
        property string pluginDir: ""
        readonly property var mainInstance: svc
        function closePanel() { ++scene.closes }
        readonly property var spectrum: QtObject {
            readonly property int bars: 24
            readonly property var levels: Array.from({ length: 24 }, (_, i) => (i % 6) / 6)
            property var owners: []
            function setActive(owner, on) {
                owners = on ? owners.filter((o) => o !== owner).concat([owner]) : owners.filter((o) => o !== owner)
            }
        }
    }

    FloatingWindow {
        color: "black"
        implicitWidth: 460
        implicitHeight: 860
        Test.TestCase { id: input; when: false }
        Mark.Panel { id: panel; x: 20; y: 20; width: 416; pluginApi: api; active: true }
    }

    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children) {
            const hit = find(child, name);
            if (hit) return hit;
        }
        return null;
    }
    function check(test, reason) { if (!test) throw new Error(reason); }

    Component.onCompleted: Tokens.controlsCrate = true

    Timer {
        interval: 700
        running: true
        onTriggered: {
            const beam = find(panel, "progressBeam");
            check(beam && typeof beam.bipolar === "boolean" && beam.interactive, "progress is the kit Beam");
            check(!beam.dragging && panel.pos === 0, "the readout shows the clock at rest");
            input.mousePress(beam, beam.width * 0.5, beam.height / 2);
            check(beam.dragging && Math.abs(panel.pos - 100) < 2, "dragging shows the dragged time");
            input.mouseRelease(beam, beam.width * 0.5, beam.height / 2);
            check(!beam.dragging && Math.abs(svc.seeked - 100) < 2, "release seeks");

            const shuffle = find(panel, "shuffleButton");
            check(shuffle.glyph === "shuffle" && shuffle.on && shuffle.implicitWidth === 44, "shuffle is the kit's plateless icon button, on");
            check(find(panel, "repeatButton").glyph === "repeat_one", "repeat one shows its glyph");
            check(!find(panel, "nextButton").enabled && find(panel, "previousButton").enabled, "transport follows the player's abilities");

            const toggle = find(panel, "eqToggle");
            check(toggle.implicitWidth === 34 && toggle.implicitHeight === 18 && toggle.on, "the equalizer on/off is the kit switch");
            toggle.activate();
            check(svc.eqSet === false, "the switch turns the equalizer off");

            const glyph = find(panel, "playGlyph");
            check(glyph && glyph.anchors.horizontalCenterOffset === 0, "the play glyph sits on the ring's centre (Solar's own optical offset)");

            const disc = find(panel, "coverDisc");
            check(disc && disc.width === disc.height && disc.width >= 64, "the cover is a round record");
            check(!disc.spinning, "reduced motion holds the record still");
            svc.reduceMotion = false;
            check(disc.spinning, "a playing record spins");
            const ring = find(panel, "spectrumRing");
            check(ring && ring.visible && ring.marks === 24, "the shell's spectrum rings the record, one mark per band");
            check(api.spectrum.owners.length === 1, "the panel asks for the analysis while it shows a playing track");
            svc.playing = false;
            check(!disc.spinning, "a paused record stops");
            check(api.spectrum.owners.length === 0, "paused, the panel releases the analysis");
            svc.playing = true;
            svc.reduceMotion = true;
            const genre = find(panel, "eqMode-genre");
            genre.clicked();
            check(svc.modes.length === 1 && svc.modes[0] === "genre", "a mode chip sets the mode");

            const state = find(panel, "stateLabel");
            check(state.tone === "active" && state.text === "Now playing" && state.font.family === Tokens.mono, "the state label is the kit's, live while playing");

            find(panel, "playButton").clicked();
            check(svc.toggles === 1, "the play button toggles");
            find(panel, "closeButton").clicked();
            check(scene.closes === 1, "the close button closes the panel");

            Tokens.controlsCrate = false;
            stock.start();
        }
    }
    Timer {
        id: stock
        interval: 400
        onTriggered: {
            check(find(panel, "eqToggle").implicitWidth === 54 && find(panel, "eqToggle").implicitHeight === 24, "the switch follows the stock kit");
            check(find(panel, "shuffleButton").implicitWidth === 26, "the icon buttons follow the stock kit");
            check(find(panel, "stateLabel").font.family === Tokens.ui, "the labels follow the stock kit");
            console.log("CRATE-MARK-KIT-PASS");
            Qt.quit();
        }
    }
}
