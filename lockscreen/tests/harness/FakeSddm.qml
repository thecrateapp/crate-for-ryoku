import QtQuick
// Session-lock style sddm object: the presence of fingerprintHint marks a session lock.
QtObject {
    property string hostName: "crate-host"
    property var fingerprintHint: ""
    property string fingerprintState: ""
    property bool fingerprintReady: false
    // True when the sensor, not a typed password, won the last unlock.
    property bool fingerprintUnlock: false
    property string keyState: ""
    // Mirrors the shim: a PIN request is dropped (state off) unless the skin draws key prompts.
    function requestKeyState(state) { keyState = (state === "pin" && !keyPrompts) ? "off" : state }
    function usePassword() { calls.push(["usePassword"]); keyState = "off" }
    property bool keyPasswordMode: true
    // Writable bool like the real shim: a skin must set it before a PIN/touch prompt is shown.
    property bool keyPrompts: false
    signal loginFailed()
    signal loginSucceeded()
    signal keyTimedOut()
    // The lock shell emits it when the secure surface is shown (again).
    signal surfaceRevealed()
    // Optional PAM text. The real shim has no such signal today; skins connect with ignoreUnknownSignals.
    signal errorMessage(string message)
    signal informationMessage(string message)
    property var calls: []
    function login(user, password, sessionIndex) { calls.push(["login", user, password, sessionIndex]) }
    function loginKeyPin(user, pin) { calls.push(["loginKeyPin", user, pin]) }
    function reboot() { calls.push(["reboot"]) }
    function powerOff() { calls.push(["powerOff"]) }
    function suspend() { calls.push(["suspend"]) }
}
