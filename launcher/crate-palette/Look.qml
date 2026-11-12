pragma Singleton

import QtQuick
import Ryoku.Ui.Singletons

// The theme-style tokens the palette uses, with stock Ryoku's look when the
// running Ryoku does not have them yet (they arrived with theme styles).
QtObject {
    readonly property color mark: Tokens.mark !== undefined ? Tokens.mark : Tokens.ink
    readonly property color hoverInk: Tokens.hoverInk !== undefined ? Tokens.hoverInk : Tokens.ink
    readonly property color caption: Tokens.caption !== undefined ? Tokens.caption : Tokens.inkFaint
    readonly property color rowWash: Tokens.rowWash !== undefined ? Tokens.rowWash : Tokens.tint10
    readonly property string navFont: Tokens.navFont !== undefined ? Tokens.navFont : Tokens.ui
    readonly property real trackNav: Tokens.trackNav !== undefined ? Tokens.trackNav : Tokens.trackLabel
}
