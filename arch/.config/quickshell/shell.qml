import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.modules

ShellRoot {
    IpcHandler {
        target: "theme-manager"
        function reload(): void {
            Theme.reloadTheme();
        }
    }

    Sidebar { id: sidebar }
    Overview { id: overview }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            readonly property bool centered: Config.layout === "centered"

            anchors { top: true; left: true; right: true }
            implicitHeight: Theme.islandHeight + 10
            exclusiveZone: Theme.islandHeight + 6
            color: "transparent"

            component Island: Rectangle {
                required property var names
                visible: names.length > 0
                radius: bar.centered ? Theme.radius : 10
                color: Theme.island
                border.width: 1
                border.color: Theme.islandBorder
                implicitWidth: row.implicitWidth + 28
                implicitHeight: Theme.islandHeight

                Behavior on implicitWidth {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: 12

                    Repeater {
                        model: parent.parent.names

                        Loader {
                            required property var modelData
                            source: "modules/" + modelData + ".qml"
                            onLoaded: {
                                if (item && item.screenName !== undefined)
                                    item.screenName = bar.modelData.name;
                            }
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 5

                Island {
                    id: leftIsland
                    anchors.left: parent.left
                    names: Config.modules.left ?? []
                }

                Island {
                    anchors.horizontalCenter: bar.centered ? parent.horizontalCenter : undefined
                    anchors.left: bar.centered ? undefined : leftIsland.right
                    anchors.leftMargin: bar.centered ? 0 : 8
                    names: Config.modules.center ?? []
                }

                Island {
                    anchors.right: parent.right
                    names: Config.modules.right ?? []
                }
            }
        }
    }
}
