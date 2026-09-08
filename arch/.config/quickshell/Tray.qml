import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 8

    Repeater {
        model: SystemTray.items

        Image {
            required property var modelData
            source: modelData.icon
            width: 16
            height: 16
            sourceSize.width: 16
            sourceSize.height: 16

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => mouse.button === Qt.LeftButton
                    ? modelData.activate()
                    : modelData.display()
            }
        }
    }
}
