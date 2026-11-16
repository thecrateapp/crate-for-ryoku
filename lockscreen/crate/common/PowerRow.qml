import QtQuick
import "i18n"

// Suspend, Reboot, Shut down. Calls the sddm object; the host refocuses the field on `activated`.
Row {
    id: root
    objectName: "powerRow"
    spacing: Math.round(CratePalette.s(20))
    signal activated()

    function call(name) {
        if (typeof sddm !== "undefined" && sddm && sddm[name]) sddm[name]();
        root.activated();
    }

    HoverLink { objectName: "powerSuspend"; text: I18n.tr("suspend"); onActivated: root.call("suspend") }
    HoverLink { objectName: "powerReboot"; text: I18n.tr("reboot"); onActivated: root.call("reboot") }
    HoverLink { objectName: "powerShutdown"; text: I18n.tr("shutdown"); onActivated: root.call("powerOff") }
}
