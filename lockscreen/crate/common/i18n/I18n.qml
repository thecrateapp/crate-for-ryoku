pragma Singleton
import QtQuick

// English base catalogue. Skins call I18n.tr("key"); an unknown key returns itself.
QtObject {
    readonly property var en: ({
        "password": "Password",
        "user": "User",
        "suspend": "Suspend",
        "reboot": "Reboot",
        "shutdown": "Shut down",
        "wrongPassword": "Wrong password",
        "securityKeyPin": "Enter the security key PIN",
        "touchKey": "Touch the security key",
        "fingerprint": "Scan your fingerprint",
        "SECURITY KEY PIN": "SECURITY KEY PIN",
        "ESC TO USE PASSWORD": "ESC TO USE PASSWORD",
        "TOUCH THE SECURITY KEY": "TOUCH THE SECURITY KEY",
        "or touch the reader": "or touch the reader",
        "scan denied, type your password": "scan denied, type your password",
        "CHECKING": "CHECKING",
        "nowPlaying": "Now playing",
        "nowPlayingInCrate": "Now playing in Crate"
    })
    function tr(key) {
        return en[key] !== undefined ? en[key] : key;
    }
}
