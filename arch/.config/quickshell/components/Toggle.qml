import QtQuick
import qs.theme

Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool on)

    implicitWidth: 38
    implicitHeight: 22
    radius: 11
    color: checked ? Theme.primary : Theme.surface_container_highest
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        x: root.checked ? root.width - width - 3 : 3
        y: 3
        width: 16
        height: 16
        radius: 8
        color: root.checked ? Theme.on_primary : Theme.fg
        Behavior on x { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
