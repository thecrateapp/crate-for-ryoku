import QtQuick
// Same shape as the shim's userModel (and SDDM's): count, lastUser, index(), data() with Qt.UserRole + 1 = name.
ListModel {
    id: m
    property string lastUser: ""
    property int lastIndex: 0
    function rowCount() { return count; }
    function index(row, col) { return row; }
    function data(row, role) {
        var item = get(row);
        if (!item) return "";
        return role === (Qt.UserRole + 2) ? item.realName : item.name;
    }
    // last: the model's lastUser (default the first name; "" for an SDDM that remembers nobody);
    // index: its lastIndex. Set before the rows, like a model that is complete when it appears.
    function setUsers(names, last, index) {
        lastUser = last !== undefined ? last : (names[0] || "");
        lastIndex = index !== undefined ? index : 0;
        clear();
        for (var i = 0; i < names.length; i++) append({ name: names[i], realName: names[i], icon: "", homeDir: "/home/" + names[i] });
    }
}
