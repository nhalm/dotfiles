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

    // busctl, not powerprofilesctl: 1.6ms a poll against 75ms.
    readonly property string iface: "org.freedesktop.UPower.PowerProfiles"
    readonly property string path: "/org/freedesktop/UPower/PowerProfiles"

    Process {
        id: get
        running: true
        command: ["busctl", "--system", "get-property", root.iface, root.path, root.iface, "ActiveProfile"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /"([a-z-]+)"/.exec(this.text);
                root.profile = m ? m[1] : "balanced";
            }
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
            Quickshell.execDetached(["busctl", "--system", "set-property",
                root.iface, root.path, root.iface, "ActiveProfile", "s", next]);
            root.profile = next;
        }
    }
}
