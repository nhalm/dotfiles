import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme

Item {
    id: root
    implicitWidth: 18
    implicitHeight: 18

    property bool powered: false
    property int connected: 0

    Process {
        id: probe
        running: true
        command: ["bash", "-c",
            "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off; " +
            "bluetoothctl devices Connected | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n");
                root.powered = l[0] === "on";
                root.connected = parseInt(l[1]) || 0;
            }
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: { probe.running = false; probe.running = true; }
    }

    Text {
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
        color: !root.powered ? Theme.dim : (root.connected > 0 ? Theme.accent : Theme.fg)
        text: !root.powered ? "󰂲" : (root.connected > 0 ? "󰂱" : "󰂯")
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => Quickshell.execDetached(mouse.button === Qt.RightButton
            ? ["blueman-manager"]
            : ["qs", "ipc", "call", "sidebar", "toggle"])
    }
}
