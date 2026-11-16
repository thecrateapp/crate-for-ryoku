import QtQuick

// Current login name. With more than one user a click cycles to the next one.
// `model` has the shape of SDDM's userModel (and the lock shim's): count, lastUser, lastIndex,
// data(index(row, 0), Qt.UserRole + 1) = name (SDDM's NameRole). Until a click picks someone the
// name follows the model: lastUser, else the user at lastIndex, else the first user. SDDM leaves
// lastUser empty when it remembers nobody; the name is then never a placeholder.
Item {
    id: root
    // Design pixels scale per skin instance: the host binds this to its own uiScale (SkinRoot).
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
        picked = true;
        currentUser = nameAt((indexOfCurrent() + 1) % userCount);
    }
    // True once a click chose the user: the model no longer moves the name.
    property bool picked: false
    function preferred() {
        if (!model) return "";
        if (model.lastUser) return String(model.lastUser);
        var byIndex = model.lastIndex !== undefined ? nameAt(Number(model.lastIndex)) : "";
        return byIndex !== "" ? byIndex : nameAt(0);
    }
    function adopt() {
        if (picked) return;
        var name = preferred();
        if (name !== "") currentUser = name;
    }
    onModelChanged: adopt()
    // The shim's ListModel gets its row after it is handed over.
    onUserCountChanged: adopt()
    Component.onCompleted: adopt()

    Connections {
        target: root.model && root.model.objectNameChanged !== undefined ? root.model : null
        ignoreUnknownSignals: true
        function onLastUserChanged() { root.adopt(); }
        function onLastIndexChanged() { root.adopt(); }
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
