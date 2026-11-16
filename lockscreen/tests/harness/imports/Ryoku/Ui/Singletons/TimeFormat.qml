pragma Singleton
import QtQuick
QtObject {
    property bool is24h: true
    property var locale: Qt.locale()
}
