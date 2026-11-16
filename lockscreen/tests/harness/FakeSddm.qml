import QtQuick
// Session-lock style sddm object: the presence of fingerprintHint marks a session lock.
QtObject {
    property string hostName: "crate-host"
    property var fingerprintHint: ""
    property string fingerprintState: ""
    property bool fingerprintReady: false
    property string keyState: ""
    property bool keyPasswordMode: true
    property var keyPrompts: []
    signal loginFailed()
    signal loginSucceeded()
    signal keyTimedOut()
    property var calls: []
    function login(user, password, sessionIndex) { calls.push(["login", user, password, sessionIndex]) }
    function loginKeyPin(user, pin) { calls.push(["loginKeyPin", user, pin]) }
    function reboot() { calls.push(["reboot"]) }
    function powerOff() { calls.push(["powerOff"]) }
    function suspend() { calls.push(["suspend"]) }
}
