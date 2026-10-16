import QtQuick
import QtQuick.Layouts
import qs.theme

Item {
    id: root

    property real low: 0
    property real high: 0
    property real min: 0
    property real max: 1
    property real marker: NaN

    function at(v) { return root.max > root.min ? (v - root.min) / (root.max - root.min) * width : 0; }

    Layout.fillWidth: true
    implicitHeight: 6

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: Theme.surface_container_highest
    }
    Rectangle {
        x: root.at(root.low)
        width: Math.max(height, root.at(root.high) - root.at(root.low))
        height: parent.height
        radius: 3
        color: Theme.primary
    }
    Rectangle {
        visible: !isNaN(root.marker)
        x: root.at(root.marker) - width / 2
        width: 6
        height: 6
        radius: 3
        color: Theme.fg
        border.width: 1
        border.color: Theme.surface_container
    }
}
