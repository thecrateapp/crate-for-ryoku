import QtQuick
import "i18n"

// Small mono line that tells which other ways in are live: key PIN, key touch, fingerprint.
Text {
    id: root
    // Design pixels scale per skin instance: the host binds this to its own uiScale (SkinRoot).
    property real uiScale: 1
    objectName: "authHint"
    property string fingerprintState: ""   // "", idle, scanning, success, fail, unavailable
    property string keyState: ""           // "", off, pin, verifying, touch
    property string authState: "idle"      // the PasswordField state
    property string notice: ""             // the PasswordField notice (KEY TIMED OUT)

    readonly property string message: {
        if (keyState === "pin") return I18n.tr("SECURITY KEY PIN") + " \u00b7 " + I18n.tr("ESC TO USE PASSWORD");
        if (keyState === "touch") return I18n.tr("TOUCH THE SECURITY KEY");
        if (notice !== "") return notice;
        if (fingerprintState === "scanning") return I18n.tr("or touch the reader");
        if (fingerprintState === "fail") return I18n.tr("scan denied, type your password");
        if (authState === "checking") return I18n.tr("CHECKING");
        return "";
    }
    text: message
    visible: message !== ""
    color: fingerprintState === "fail" && keyState !== "pin" && keyState !== "touch" ? CratePalette.danger
         : (fingerprintState === "scanning" || keyState === "pin" || keyState === "touch") ? CratePalette.cyanHi
         : CratePalette.faint
    elide: Text.ElideRight
    maximumLineCount: 1
    font.family: CratePalette.monoFamily
    font.pixelSize: Math.round(CratePalette.s(12, root.uiScale))
    font.letterSpacing: Math.round(CratePalette.s(12, root.uiScale)) * 0.12
    font.capitalization: Font.AllUppercase
}
