import QtQuick
import "i18n"

// One line of danger-coloured text under the field. Reserves its height so nothing jumps.
Text {
    id: root
    // Design pixels scale per skin instance: the host binds this to its own uiScale (SkinRoot).
    property real uiScale: 1
    objectName: "errorLine"
    property bool shown: false

    visible: shown && text !== ""
    color: CratePalette.danger
    elide: Text.ElideRight
    maximumLineCount: 1
    height: implicitHeight
    font.family: CratePalette.monoFamily
    font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
    font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.12
    font.capitalization: Font.AllUppercase
    Accessible.role: Accessible.AlertMessage
    Accessible.name: text
}
