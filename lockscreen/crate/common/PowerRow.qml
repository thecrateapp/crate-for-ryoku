import QtQuick
import "i18n"

// Suspend, Reboot, Shut down. Calls the sddm object; the host refocuses the field on `activated`.
Row {
    id: root
    // Design pixels scale per skin instance: the host binds this to its own uiScale (SkinRoot).
    property real uiScale: 1
    objectName: "powerRow"
    spacing: Math.round(CratePalette.s(20, root.uiScale))
    signal activated()

    function call(name) {
        if (typeof sddm !== "undefined" && sddm && sddm[name]) sddm[name]();
        root.activated();
    }

    HoverLink { uiScale: root.uiScale; objectName: "powerSuspend"; text: I18n.tr("suspend"); onActivated: root.call("suspend") }
    HoverLink { uiScale: root.uiScale; objectName: "powerReboot"; text: I18n.tr("reboot"); onActivated: root.call("reboot") }
    HoverLink { uiScale: root.uiScale; objectName: "powerShutdown"; text: I18n.tr("shutdown"); onActivated: root.call("powerOff") }
}
