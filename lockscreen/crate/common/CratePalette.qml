pragma Singleton
import QtQuick

// Crate tokens for the lock skins. Colours are fixed: the skins keep one identity in the
// session lock and in SDDM. There is deliberately no static import of Ryoku.Ui.Singletons
// (the SDDM greeter may not have that module). In session-lock mode Main calls linkTokens(),
// which loads it dynamically; reduceMotion falls back to false when it is unavailable.
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

    property bool reduceMotion: false
    property bool tokensLinked: false
    property var tokensProbe: null

    function linkTokens() {
        if (tokensProbe)
            return;
        try {
            tokensProbe = Qt.createQmlObject(
                'import QtQuick\nimport Ryoku.Ui.Singletons as R\n'
                + 'QtObject { readonly property bool reduceMotion: R.Tokens.controlsCrate === true && R.Tokens.reduceMotion === true }',
                palette, "CratePaletteTokens");
            if (!tokensProbe)
                return;
            reduceMotion = Qt.binding(() => tokensProbe.reduceMotion);
            tokensLinked = true;
        } catch (e) {
            tokensProbe = null;
            reduceMotion = false;
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
