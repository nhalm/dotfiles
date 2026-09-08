import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import qs.theme

RowLayout {
    id: tray
    spacing: 8

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: item
            required property var modelData

            implicitWidth: 20
            implicitHeight: 20
            Layout.alignment: Qt.AlignVCenter
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            Image {
                id: icon
                anchors.centerIn: parent
                source: item.modelData.icon
                width: 18
                height: 18
                sourceSize.width: 18
                sourceSize.height: 18
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !icon.visible
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 13
                text: (item.modelData.title || item.modelData.id || "?").charAt(0).toUpperCase()
            }

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton && !modelData.onlyMenu)
                    modelData.activate();
                else if (modelData.hasMenu)
                    menu.open();
            }

            QsMenuAnchor {
                id: menu
                menu: item.modelData.menu
                anchor.item: item
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
        }
    }
}
