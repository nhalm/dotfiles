import Quickshell
import QtQuick
import qs.theme

Item {
    implicitWidth: 18
    implicitHeight: 18

    Text {
        anchors.centerIn: parent
        font.pixelSize: Theme.fontSize + 2
        color: hover.hovered ? Theme.accent : Theme.fg
        text: "󰣇"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => Quickshell.execDetached(
            mouse.button === Qt.RightButton ? ["ghostty"] : ["hyprlauncher"])
    }
}
