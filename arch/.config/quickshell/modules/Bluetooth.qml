import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components

Item {
    id: root

    implicitWidth: 18
    implicitHeight: 18

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var paired: (adapter?.devices.values ?? []).filter(d => d.paired)
    readonly property var connected: paired.filter(d => d.connected)

    function glyph(d) {
        const i = d.icon ?? "";
        return i.includes("keyboard") ? "󰌌"
            : i.includes("mouse") ? "󰍽"
            : i.includes("audio") || i.includes("headset") || i.includes("headphone") ? "󰋋"
            : i.includes("phone") ? "󰏲"
            : "󰂯";
    }

    function status(d) {
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (d.connected && d.batteryAvailable)
            return "Battery " + Math.round(d.battery * 100) + "%";
        return d.connected ? "Connected" : "Not connected";
    }

    Text {
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 3
        color: hover.hovered || popup.visible ? Theme.primary : root.powered ? Theme.fg : Theme.dim
        text: root.powered ? "\u{f294}" : "󰂲"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton
            ? Quickshell.execDetached(["blueman-manager"])
            : popup.toggle()
    }

    BarPopup {
        id: popup
        chip: root
        chipHovered: hover.hovered

        Hero {
            eyebrow: "Bluetooth"
            value: root.powered ? "On" : "Off"
            subtitle: !root.powered ? "" : root.connected.length ? root.connected.length + " connected" : "No devices connected"
            toggleVisible: root.adapter !== null
            checked: root.powered
            onToggled: on => root.adapter.enabled = on
        }

        Section {
            visible: root.powered && root.connected.length > 0
            title: "Connected"
            Repeater {
                model: root.connected
                ListRow {
                    required property var modelData
                    icon: root.glyph(modelData)
                    title: modelData.name
                    subtitle: root.status(modelData)
                    selected: true
                    onClicked: modelData.disconnect()
                }
            }
        }

        Section {
            visible: root.powered && root.paired.length > root.connected.length
            title: "Paired"
            Repeater {
                model: root.paired.filter(d => !d.connected)
                ListRow {
                    required property var modelData
                    icon: root.glyph(modelData)
                    title: modelData.name
                    subtitle: root.status(modelData)
                    onClicked: modelData.connect()
                }
            }
        }

        Text {
            visible: root.powered && root.paired.length === 0
            text: "No paired devices"
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }

        Footer {
            text: "Bluetooth settings…"
            onClicked: {
                popup.visible = false;
                Quickshell.execDetached(["blueman-manager"]);
            }
        }
    }
}
