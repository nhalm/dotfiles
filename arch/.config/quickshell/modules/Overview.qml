import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

PanelWindow {
    id: root

    property bool isOpen: false

    visible: isOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: WlrLayershell.Ignore

    IpcHandler {
        target: "overview"
        function toggle(): void { root.isOpen = !root.isOpen; }
        function close(): void { root.isOpen = false; }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.isOpen = false
    }

    function focusWindow(address) {
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })");
        root.isOpen = false;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: root.isOpen = false
        }
    }

    ScrollView {
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 1400)
        height: Math.min(parent.height - 120, grid.implicitHeight + 40)
        clip: true

        ColumnLayout {
            id: grid
            width: parent.width
            spacing: 24

            Repeater {
                model: Hyprland.workspaces

                ColumnLayout {
                    required property var modelData
                    readonly property var clients: Hyprland.toplevels.values.filter(
                        t => t.workspace && t.workspace.id === modelData.id)

                    visible: clients.length > 0
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        text: "Workspace " + modelData.id
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 12

                        Repeater {
                            model: parent.parent.clients

                            Rectangle {
                                required property var modelData
                                width: 260
                                height: 90
                                radius: 10
                                color: hover.hovered ? Theme.surface_container_high : Theme.surface_container
                                border.width: 1
                                border.color: hover.hovered ? Theme.primary : Theme.outline_variant

                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        color: Theme.on_surface
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                        text: modelData.title || "(untitled)"
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        color: Theme.on_surface_variant
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        opacity: 0.8
                                        elide: Text.ElideRight
                                        text: modelData.lastIpcObject?.class ?? ""
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                HoverHandler { id: hover }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.focusWindow(modelData.address)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
