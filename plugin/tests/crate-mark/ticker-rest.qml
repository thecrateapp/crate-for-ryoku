import QtQuick
import Quickshell

// crate-mark's title ticker rolls a long title twice and then rests on its start
// (no animation running), and a new title rolls again.
ShellRoot {
    FloatingWindow {
        implicitWidth: 200
        implicitHeight: 40
        TrackTicker {
            id: ticker
            width: 80
            height: 20
            text: "NIÑA COYOTE eta CHICO TORNADO · Dúas"
            playing: true
            continuous: true
            elideWhenStill: true
        }
    }

    Timer {
        id: early
        interval: 300
        running: true
        onTriggered: {
            if (!ticker.scrolling || ticker.rested) throw new Error("a long playing title rolls first");
            // two revolutions take travel * 20 ms each
            rested.interval = Math.round(ticker.travel * 20 * 2) + 600;
            rested.start();
        }
    }
    Timer {
        id: rested
        onTriggered: {
            if (!ticker.rested || ticker.scrolling) throw new Error("after two rolls the title rests");
            ticker.text = "Another long title that overflows the viewport";
            again.start();
        }
    }
    Timer {
        id: again
        interval: 200
        onTriggered: {
            if (ticker.rested || !ticker.scrolling) throw new Error("a new title rolls again");
            console.log("TICKER-PROBE-PASS");
            Qt.quit();
        }
    }
}
