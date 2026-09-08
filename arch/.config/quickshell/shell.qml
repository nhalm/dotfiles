import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            implicitHeight: 42
            exclusiveZone: 38
            color: "transparent"

            readonly property color island: "#24283b"
            readonly property color fg: "#c0caf5"
            readonly property color dim: "#565f89"
            readonly property color accent: "#7aa2f7"

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                radius: 14
                color: bar.island
                implicitWidth: content.implicitWidth + 24
                implicitHeight: 30

                RowLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 12

                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: Hyprland.workspaces

                            Rectangle {
                                required property var modelData
                                visible: modelData.monitor?.name === bar.modelData.name
                                         && (modelData.focused || modelData.lastIpcObject?.windows > 0)
                                implicitWidth: visible ? 22 : 0
                                implicitHeight: 20
                                radius: 7
                                color: modelData.focused ? bar.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.id
                                    font.pixelSize: 11
                                    color: modelData.focused ? "#1f2335" : bar.dim
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData.id + " })")
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        color: bar.dim
                        opacity: 0.5
                    }

                    Text {
                        color: bar.fg
                        font.pixelSize: 12
                        text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
                        SystemClock { id: clock; precision: SystemClock.Minutes }
                    }

                    Text {
                        visible: UPower.displayDevice.isLaptopBattery && UPower.onBattery
                        color: UPower.displayDevice.percentage < 0.2 ? "#f7768e" : bar.fg
                        font.pixelSize: 12
                        text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        color: bar.dim
                        opacity: 0.5
                        visible: SystemTray.items.values.length > 0
                    }

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
                }
            }
        }
    }
}
