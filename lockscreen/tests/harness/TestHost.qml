import QtQuick
// Hosts a skin the way qylock does: sddm, config and userModel are visible to the loaded Main.qml.
Item {
    id: host
    property string skin
    property var sddm
    property var config: ({})
    property var userModel: ({})
    property alias item: loader.item
    Loader { id: loader; anchors.fill: parent; source: host.skin }
}
