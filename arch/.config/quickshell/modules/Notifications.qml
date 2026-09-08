import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme

Item {
    id: root
    implicitWidth: 18
    implicitHeight: 18

    property int count: 0
    property bool dnd: false

    Process {
        running: true
        command: ["swaync-client", "-swb"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const s = JSON.parse(line);
                    root.count = s.count ?? 0;
                    root.dnd = (s.class ?? "").indexOf("dnd") !== -1;
                } catch (e) {}
            }
        }
    }

    Text {
        anchors.centerIn: parent
        font.pixelSize: Theme.fontSize + 1
        color: root.dnd ? Theme.dim : (root.count > 0 ? Theme.accent : Theme.fg)
        text: root.dnd ? "󰂛" : (root.count > 0 ? "󱅫" : "󰂚")
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => Quickshell.execDetached(
            mouse.button === Qt.RightButton
                ? ["swaync-client", "-d", "-sw"]
                : ["swaync-client", "-t", "-sw"])
    }
}
