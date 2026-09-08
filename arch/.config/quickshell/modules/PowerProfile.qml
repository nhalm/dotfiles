import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme

Item {
    id: root
    implicitWidth: 18
    implicitHeight: 18

    property string profile: "balanced"

    readonly property var icons: ({
        "power-saver": "󰾆",
        "balanced": "󰾅",
        "performance": "󰓅"
    })

    Process {
        id: get
        running: true
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.profile = this.text.trim() || "balanced"
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: { get.running = false; get.running = true; }
    }

    Text {
        anchors.centerIn: parent
        font.pixelSize: Theme.fontSize + 1
        color: root.profile === "performance" ? Theme.warn : Theme.fg
        text: root.icons[root.profile] ?? "󰾅"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            const order = ["power-saver", "balanced", "performance"];
            const next = order[(order.indexOf(root.profile) + 1) % order.length];
            Quickshell.execDetached(["powerprofilesctl", "set", next]);
            root.profile = next;
        }
    }
}
