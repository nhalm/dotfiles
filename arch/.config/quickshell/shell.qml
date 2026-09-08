import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: 34
            color: "#1f2335"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 12

                RowLayout {
                    spacing: 4
                    Repeater {
                        model: Hyprland.workspaces
                        Rectangle {
                            required property var modelData
                            implicitWidth: 26
                            implicitHeight: 22
                            radius: 6
                            color: modelData.focused ? "#7aa2f7" : "#24283b"
                            Text {
                                anchors.centerIn: parent
                                text: modelData.id
                                color: parent.color === "#7aa2f7" ? "#1f2335" : "#565f89"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: "#a9b1d6"
                    text: Hyprland.focusedMonitor?.activeWorkspace?.lastIpcObject?.lastwindowtitle ?? ""
                }

                RowLayout {
                    spacing: 8
                    Repeater {
                        model: SystemTray.items
                        Image {
                            required property var modelData
                            source: modelData.icon
                            width: 18
                            height: 18
                            sourceSize.width: 18
                            sourceSize.height: 18
                        }
                    }
                }

                Text {
                    color: "#c0caf5"
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                }
            }
        }
    }
}
