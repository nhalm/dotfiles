import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.theme

RowLayout {
    id: root
    spacing: 5
    visible: count > 0

    property int count: 0

    Process {
        id: check
        running: true
        command: ["sh", "-c", "checkupdates 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.count = parseInt(this.text.trim()) || 0
        }
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: { check.running = false; check.running = true; }
    }

    Text {
        font.pixelSize: Theme.fontSize
        color: Theme.accent
        text: "󰚰"
    }

    Text {
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        text: root.count
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["ghostty", "-e", "sh", "-c", "sudo pacman -Syu; read -n1"])
    }
}
