pragma Singleton
import QtQuick

// English base catalogue. Skins call I18n.tr("key"); an unknown key returns itself.
QtObject {
    readonly property var en: ({
        "password": "Password",
        "suspend": "Suspend",
        "reboot": "Reboot",
        "shutdown": "Shut down",
        "wrongPassword": "Wrong password",
        "securityKeyPin": "Enter the security key PIN",
        "touchKey": "Touch the security key",
        "fingerprint": "Scan your fingerprint"
    })
    function tr(key) {
        return en[key] !== undefined ? en[key] : key;
    }
}
