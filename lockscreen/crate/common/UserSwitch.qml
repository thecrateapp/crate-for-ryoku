import QtQuick

// Current login name. With more than one user a click cycles to the next one.
// `model` has the shape of SDDM's userModel: count, lastUser, data(index(row, 0), Qt.UserRole + 1) = name.
Item {
    id: root
    // Design pixels scale per skin instance: the host binds this to its own height / 1200.
    property real uiScale: 1
    objectName: "userSwitch"
    property var model: null
    property string currentUser: ""
    readonly property int userCount: model && model.count !== undefined ? model.count : 0
    readonly property bool switchable: userCount > 1
    property alias label: link.label
    signal activated()

    implicitWidth: link.implicitWidth
    implicitHeight: link.implicitHeight

    function nameAt(row) {
        if (!model || row < 0 || row >= userCount) return "";
        return String(model.data(model.index(row, 0), Qt.UserRole + 1));
    }
    function indexOfCurrent() {
        for (var i = 0; i < userCount; i++) if (nameAt(i) === currentUser) return i;
        return -1;
    }
    function cycle() {
        if (!switchable) return;
        currentUser = nameAt((indexOfCurrent() + 1) % userCount);
    }
    function adopt() { if (currentUser === "" && model && model.lastUser) currentUser = String(model.lastUser); }
    onModelChanged: adopt()
    Component.onCompleted: adopt()

    Connections {
        target: root.model && root.model.objectNameChanged !== undefined ? root.model : null
        ignoreUnknownSignals: true
        function onLastUserChanged() { root.adopt(); }
    }

    HoverLink {
        id: link
        objectName: "userSwitchLink"
        anchors.fill: parent
        uiScale: root.uiScale
        text: root.currentUser
        interactive: root.switchable
        onActivated: { root.cycle(); root.activated(); }
    }
}
