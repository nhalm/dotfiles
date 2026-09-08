import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.theme

Item {
    id: root
    implicitWidth: 18
    implicitHeight: 18

    Text {
        anchors.centerIn: parent
        font.pixelSize: Theme.fontSize + 1
        color: hover.hovered ? Theme.warn : Theme.fg
        text: "⏻"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        onClicked: menu.visible = !menu.visible
    }

    PanelWindow {
        id: menu
        visible: false
        color: "transparent"
        implicitWidth: 200
        implicitHeight: actions.implicitHeight + 20
        anchors { top: true; right: true }
        margins { top: 48; right: 12 }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.island
            border.width: 1
            border.color: Theme.islandBorder

            ColumnLayout {
                id: actions
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2

                Repeater {
                    model: [
                        { label: "Lock", cmd: ["loginctl", "lock-session"] },
                        { label: "Suspend", cmd: ["systemctl", "suspend"] },
                        { label: "Log out", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
                        { label: "Reboot", cmd: ["systemctl", "reboot"] },
                        { label: "Shut down", cmd: ["systemctl", "poweroff"] }
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 8
                        color: itemHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            font.pixelSize: Theme.fontSize
                            color: Theme.fg
                            text: modelData.label
                        }

                        HoverHandler { id: itemHover }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                menu.visible = false;
                                Quickshell.execDetached(modelData.cmd);
                            }
                        }
                    }
                }
            }
        }
    }
}
