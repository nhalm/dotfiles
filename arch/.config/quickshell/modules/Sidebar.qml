import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

PanelWindow {
    id: root
    property bool shown: false

    visible: shown
    color: "transparent"
    implicitWidth: 340
    anchors { top: true; right: true; bottom: true }
    margins { top: 48; right: 12; bottom: 12 }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    IpcHandler {
        target: "sidebar"
        function toggle(): void { root.shown = !root.shown; }
        function close(): void { root.shown = false; }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }

    component Toggle: Rectangle {
        required property string label
        required property bool active
        property var action
        Layout.fillWidth: true
        implicitHeight: 44
        radius: 12
        color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                      : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        border.color: active ? Theme.primary : "transparent"

        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            color: Theme.fg
            font.pixelSize: Theme.fontSize
            text: parent.label
        }

        MouseArea {
            anchors.fill: parent
            onClicked: if (parent.action) parent.action()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.island
        border.width: 1
        border.color: Theme.islandBorder

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Text {
                color: Theme.fg
                font.pixelSize: 16
                text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
            }

            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Layout.fillWidth: true

                Toggle {
                    label: "Network"
                    active: true
                    action: () => Quickshell.execDetached(["nm-connection-editor"])
                }
                Toggle {
                    label: "Bluetooth"
                    active: true
                    action: () => Quickshell.execDetached(["blueman-manager"])
                }
                Toggle {
                    label: "Wallpaper"
                    active: false
                    action: () => Quickshell.execDetached([
                        Quickshell.env("HOME") + "/.local/scripts/wallpaper.sh"])
                }
                Toggle {
                    label: "Light / Dark"
                    active: false
                    action: () => Quickshell.execDetached([
                        Quickshell.env("HOME") + "/.local/scripts/theme-mode.sh"])
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    color: Theme.dim
                    font.pixelSize: 11
                    text: "Volume  " + (root.sink?.audio ? Math.round(root.sink.audio.volume * 100) : 0) + "%"
                }

                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: root.sink?.audio?.volume ?? 0
                    onMoved: if (root.sink?.audio) root.sink.audio.volume = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: UPower.displayDevice.isLaptopBattery
                Text {
                    color: Theme.dim
                    font.pixelSize: 11
                    text: "Battery"
                }
                Item { Layout.fillWidth: true }
                Text {
                    color: Theme.fg
                    font.pixelSize: 11
                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
