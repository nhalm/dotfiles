import Quickshell
import QtQuick
import QtQuick.Layouts

ShellRoot {
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
                default property alias content: inner.data
                radius: bar.centered ? Theme.radius : 10
                color: Theme.island
                border.width: 1
                border.color: Theme.islandBorder
                implicitWidth: inner.implicitWidth + 28
                implicitHeight: Theme.islandHeight

                Behavior on implicitWidth {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    id: inner
                    anchors.centerIn: parent
                    spacing: 12
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
                    Workspaces { screenName: bar.modelData.name }
                }

                Island {
                    anchors.horizontalCenter: bar.centered ? parent.horizontalCenter : undefined
                    anchors.left: bar.centered ? undefined : leftIsland.right
                    anchors.leftMargin: bar.centered ? 0 : 8
                    Status {}
                }

                Island {
                    anchors.right: parent.right
                    visible: tray.implicitWidth > 0
                    Tray { id: tray }
                }
            }
        }
    }
}
