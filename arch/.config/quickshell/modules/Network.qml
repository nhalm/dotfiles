import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.theme

Item {
    id: root
    implicitWidth: 18
    implicitHeight: 18

    property string kind: "none"
    property int strength: 0
    property string name: ""

    Process {
        id: probe
        running: true
        command: ["bash", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device status | grep -m1 ':connected:' || true; " +
            "nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | grep -m1 '^\\*' || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l !== "");
                root.kind = "none";
                root.name = "";
                root.strength = 0;
                for (const l of lines) {
                    if (l.indexOf(":connected:") !== -1) {
                        const f = l.split(":");
                        root.kind = f[0] === "wifi" ? "wifi" : "ethernet";
                        root.name = f[2] ?? "";
                    } else if (l.charAt(0) === "*") {
                        root.strength = parseInt(l.split(":")[1]) || 0;
                    }
                }
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
        color: root.kind === "none" ? Theme.dim : Theme.fg
        text: root.kind === "ethernet" ? "󰈀"
            : root.kind === "none" ? "󰤮"
            : root.strength >= 70 ? "󰤨"
            : root.strength >= 40 ? "󰤥"
            : "󰤟"
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => Quickshell.execDetached(mouse.button === Qt.RightButton
            ? ["nm-connection-editor"]
            : ["qs", "ipc", "call", "sidebar", "toggle"])
    }
}
