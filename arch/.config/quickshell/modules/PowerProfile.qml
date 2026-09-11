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

    // busctl rather than `powerprofilesctl get`, which is a python script that
    // imports gi on every call: 75ms of CPU against busctl's 1.6ms, and this
    // polls every 10s forever. Both work here -- the session's PATH puts the
    // mise shims last, so powerprofilesctl finds the system python. It is an
    // interactive shell, where `mise activate` puts mise's python first, that
    // cannot run it at all.
    readonly property string iface: "org.freedesktop.UPower.PowerProfiles"
    readonly property string path: "/org/freedesktop/UPower/PowerProfiles"

    Process {
        id: get
        running: true
        command: ["busctl", "--system", "get-property", root.iface, root.path, root.iface, "ActiveProfile"]
        stdout: StdioCollector {
            // prints: s "balanced"
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
