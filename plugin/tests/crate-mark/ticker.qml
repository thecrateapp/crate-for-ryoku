import QtQuick
import QtTest as Test
import Quickshell
import "content" as Mark

ShellRoot {
    id: scene
    QtObject {
        id: playback
        property bool installed: true
        property bool playing: true
        property bool hasTrack: true
        property bool stopped: false
        property bool reduceMotion: false
        property string title: "Umbral"
        property string artist: ""
    }
    QtObject {
        id: api
        property var pluginSettings: ({})
        readonly property var mainInstance: playback
        property int toggles: 0
        function togglePanel() { ++toggles }
    }
    FloatingWindow {
        implicitWidth: 420
        implicitHeight: 80
        Test.TestCase { id: input; when: false }
        Mark.Widget {
            id: widget
            pluginApi: api
            active: true
            widthBudget: 220
            width: implicitWidth
            height: 32
            property int closes: 0
            onRequestClose: ++closes
        }
    }

    function check(result, message) {
        if (!result) throw Error(message)
    }
    function named(name) {
        const child = input.findChild(widget, name)
        check(child, "missing " + name)
        return child
    }
    function verify() {
        const logo = named("crateMarkLogo")
        const bars = named("cratePlayingBars")
        const viewport = named("crateTrackViewport")
        const title = named("crateTrackText")
        const offset = () => title.mapToItem(viewport, 0, 0).x
        const stationary = () => Math.abs(offset()) < 0.5
        const tick = () => input.wait(40)
        const longTitle = "Antes de que despierte la ciudad, sesión de madrugada en directo"

        check(logo.visible && bars.visible && viewport.visible, "default playing presentation")
        check(title.text === "Umbral", "a track may have no artist")
        check(logo.mapToItem(widget, logo.width, 0).x <= bars.mapToItem(widget, 0, 0).x
              && bars.mapToItem(widget, bars.width, 0).x <= viewport.mapToItem(widget, 0, 0).x,
              "the playing bars belong between the logo and title")
        check(!viewport.scrolling && stationary(), "short text should stay in place")

        playback.artist = "Marea Lunar"
        playback.title = longTitle
        tick()
        check(title.text === "Marea Lunar – " + longTitle, "artist and title")
        check(viewport.clip && widget.implicitWidth <= widget.widthBudget + 1, "host budget and clipping")
        check(title.elide === Text.ElideNone && !title.truncated && title.contentWidth > viewport.width && Math.abs(title.contentWidth - title.width) < 2, "entire long title must render before viewport clipping")
        const deadline = Date.now() + 4500
        while (offset() >= -2 && Date.now() < deadline) input.wait(30)
        check(offset() < -2, "long text must actually move")
        playback.title = "Tema distinto con un título largo que también necesita desplazamiento"
        tick()
        check(stationary(), "changing track should return to the beginning")

        playback.playing = false
        tick()
        check(!bars.visible && viewport.visible && stationary() && title.elide === Text.ElideRight, "paused track remains readable")
        check(!viewport.scrolling, "paused track must stay still")

        playback.reduceMotion = true
        playback.playing = true
        tick()
        check(bars.visible && viewport.visible && !viewport.scrolling && stationary(), "reduced motion keeps the playing indicator and text static")
        const barShape = bars.childAt(1, bars.height - 1)
        const barHeight = barShape.height
        input.wait(400)
        check(barShape.height === barHeight, "reduced motion must stop the playing bars")
        playback.reduceMotion = false
        widget.active = false
        tick()
        check(!viewport.scrolling && stationary(), "inactive host should suspend motion")
        widget.active = true

        playback.stopped = true
        tick()
        check(!viewport.visible, "stop clears retained metadata from the bar")
        playback.stopped = false

        widget.s = 1.5
        widget.widthBudget = 110
        api.pluginSettings = ({ showLabel: true })
        tick()
        check(widget.implicitWidth <= 111, "scaled budget " + widget.widthBudget + " got " + widget.implicitWidth + " viewport " + viewport.width)
        widget.s = 1
        widget.widthBudget = 220
        api.pluginSettings = ({ nowPlaying: "indicator" })
        tick()
        check(bars.visible && !viewport.visible, "indicator preference")
        api.pluginSettings = ({ nowPlaying: "off" })
        tick()
        check(logo.visible && !bars.visible && !viewport.visible, "off preference")

        api.pluginSettings = ({})
        playback.hasTrack = false
        playback.playing = false
        tick()
        check(logo.visible && !bars.visible && !viewport.visible, "idle, no track")
        input.mouseClick(widget, widget.width / 2, widget.height / 2, Qt.LeftButton)
        check(api.toggles === 1 && !playback.playing, "click opens the panel without starting playback")
        widget.open = true
        input.mouseClick(widget, widget.width / 2, widget.height / 2, Qt.LeftButton)
        check(widget.closes === 1 && api.toggles === 1, "click on the open view requests close")
        playback.installed = false
        tick()
        check(!widget.visible && widget.implicitWidth === 0, "Crate is not installed")
    }
    Timer {
        running: true
        interval: 200
        onTriggered: {
            try {
                scene.verify()
                console.log("CRATE-MARK-TICKER-PASS")
            } catch (error) {
                console.error("CRATE-MARK-TICKER-FAIL", error)
            }
            Qt.quit()
        }
    }
}
