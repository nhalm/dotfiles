import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    function bytes(b) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < units.length - 1) {
            b /= 1024;
            i++;
        }
        return { value: b >= 100 || i === 0 ? Math.round(b).toString() : b.toFixed(1), unit: units[i] };
    }

    function joined(b) {
        const v = bytes(b);
        return v.value + " " + v.unit;
    }

    function duration(s) {
        const d = Math.floor(s / 86400);
        const h = Math.floor(s % 86400 / 3600);
        const m = Math.floor(s % 3600 / 60);
        return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
    }

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 4
        color: hover.hovered || popup.visible ? Theme.primary : Perf.cpu >= 85 ? Theme.warn : Theme.fg
        text: "\u{f035b}"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton
            ? Quickshell.execDetached(["ghostty", "-e", "btop"])
            : popup.toggle()
    }

    Binding {
        target: Perf
        property: "detailed"
        value: popup.visible
    }

    BarPopup {
        id: popup
        chip: root
        chipHovered: hover.hovered
        implicitWidth: 380

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            StatTile {
                label: "CPU"
                value: Math.round(Perf.cpu).toString()
                unit: "%"
                detail: Perf.history.length ? "Peak " + Math.round(Math.max(...Perf.history)) + "% · load " + Perf.load.split(" ")[0] : ""
                Sparkline {
                    values: Perf.history
                    ceiling: 100
                    implicitHeight: 40
                }
            }
            StatTile {
                label: "Memory"
                value: root.bytes(Perf.memUsed).value
                unit: root.bytes(Perf.memUsed).unit
                detail: "of " + root.joined(Perf.memTotal)
                Sparkline {
                    values: Perf.memHistory
                    ceiling: 100
                    color: Theme.tertiary
                    implicitHeight: 40
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 28
            spacing: 2
            Repeater {
                model: Perf.cores
                Rectangle {
                    required property real modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 2
                    color: Theme.surface_container_highest
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * modelData / 100)
                        radius: 2
                        color: modelData >= 85 ? Theme.warn : Theme.primary
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            StatTile {
                label: "Uptime"
                value: root.duration(Perf.uptime)
                detail: Perf.cores.length + " threads"
            }
            StatTile {
                label: "Swap"
                value: root.bytes(Perf.swapUsed).value
                unit: root.bytes(Perf.swapUsed).unit
                detail: "of " + root.joined(Perf.swapTotal)
            }
            StatTile {
                label: "Disk"
                value: Perf.diskTotal ? Math.round(Perf.diskUsed / Perf.diskTotal * 100).toString() : "–"
                unit: "%"
                detail: root.joined(Perf.diskTotal - Perf.diskUsed) + " free"
            }
        }

        Section {
            title: "Top processes"

            RowLayout {
                spacing: 6
                Repeater {
                    model: [["cpu", "CPU"], ["memory", "Memory"]]
                    Rectangle {
                        required property var modelData
                        implicitWidth: tab.implicitWidth + 16
                        implicitHeight: 22
                        radius: 11
                        color: Perf.sort === modelData[0] ? Theme.primary : Theme.surface_container_high
                        Text {
                            id: tab
                            anchors.centerIn: parent
                            text: modelData[1]
                            color: Perf.sort === modelData[0] ? Theme.on_primary : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Perf.sort = modelData[0]
                        }
                    }
                }
            }

            Repeater {
                model: Perf.processes
                ListRow {
                    required property var modelData
                    implicitHeight: 32
                    icon: "\u{f0233}"
                    title: modelData.name
                    subtitle: Perf.sort === "cpu" ? root.joined(modelData.memory) : modelData.cpu.toFixed(1) + "%"
                    trailing: Perf.sort === "cpu" ? modelData.cpu.toFixed(1) + "%" : root.joined(modelData.memory)
                    onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
                }
            }
        }

        Footer {
            text: "Open btop"
            onClicked: {
                popup.visible = false;
                Quickshell.execDetached(["ghostty", "-e", "btop"]);
            }
        }
    }
}
