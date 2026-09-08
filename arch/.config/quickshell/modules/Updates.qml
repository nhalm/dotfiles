import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import qs.theme

Item {
    id: root

    property int count: 0

    // Kept independent of the effective `visible` property: visible is
    // inherited, so binding layout size to it latches false and never recovers.
    readonly property bool collapsed: count <= 0

    visible: !collapsed
    implicitWidth: collapsed ? 0 : row.implicitWidth
    implicitHeight: row.implicitHeight

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

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.accent
            text: "󰚰"
        }

        Text {
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            color: Theme.fg
            text: root.count
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["ghostty", "-e", "sh", "-c", "sudo pacman -Syu; read -n1"])
    }
}
