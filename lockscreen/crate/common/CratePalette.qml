pragma Singleton
import QtQuick
import Ryoku.Ui.Singletons as Ryoku

// Crate tokens for the lock skins. Colours are fixed: the skins keep one identity in the
// session lock and in SDDM, so nothing here reads Tokens values. Tokens is consulted only
// for reduceMotion, and only when Tokens.controlsCrate is true (the Ryoku shell is the one
// running us); SDDM mode never depends on it.
QtObject {
    id: palette

    readonly property color canvas: "#0a0a0f"
    readonly property color text: "#f1f5f9"
    readonly property color secondary: Qt.rgba(241 / 255, 245 / 255, 249 / 255, 0.62)
    readonly property color faint: Qt.rgba(241 / 255, 245 / 255, 249 / 255, 0.42)
    readonly property color hairline: Qt.rgba(241 / 255, 245 / 255, 249 / 255, 0.1)
    readonly property color cyan: "#06b6d4"
    readonly property color cyanHi: "#67e8f9"
    readonly property color danger: "#ef4444"
    readonly property real radius: 6

    readonly property bool reduceMotion: {
        try {
            return Ryoku.Tokens.controlsCrate === true && Ryoku.Tokens.reduceMotion === true;
        } catch (e) {
            return false;
        }
    }

    readonly property FontLoader displayLoader: FontLoader { source: Qt.resolvedUrl("fonts/BricolageGrotesque.ttf") }
    readonly property FontLoader monoLoader: FontLoader { source: Qt.resolvedUrl("fonts/JetBrainsMono-Regular.ttf") }
    readonly property string displayFamily: displayLoader.status === FontLoader.Ready ? displayLoader.name : ""
    readonly property string monoFamily: monoLoader.status === FontLoader.Ready ? monoLoader.name : ""
    readonly property bool fontsReady: displayLoader.status === FontLoader.Ready && monoLoader.status === FontLoader.Ready

    // Scales a design pixel (authored for a 1200 px tall screen) to the actual screen.
    function s(px) {
        return px * (Screen.height > 0 ? Screen.height / 1200 : 1);
    }
}
