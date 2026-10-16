import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme
import qs.components

Item {
    id: root

    implicitWidth: 18
    implicitHeight: 18

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var active: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property int signal: Math.round((active?.signalStrength ?? 0) * 100)
    readonly property string kind: wired ? "ethernet" : active ? "wifi" : "none"
    readonly property string iface: (wired ?? (active ? wifi : null))?.name ?? ""

    readonly property var networks: {
        const seen = {};
        return (wifi?.networks.values ?? [])
            .filter(n => !n.connected && n.name !== "")
            .sort((a, b) => (b.known - a.known) || (b.signalStrength - a.signalStrength))
            .filter(n => seen[n.name] ? false : (seen[n.name] = true));
    }

    property var pending: null
    property string ip: ""
    property var down: []
    property var up: []
    property var last: null

    function glyph(strength) {
        return strength >= 70 ? "󰤨" : strength >= 40 ? "󰤥" : "󰤟";
    }

    function rate(b) {
        if (b >= 1000000)
            return { value: (b / 1000000).toFixed(1), unit: "MB/s" };
        if (b >= 1000)
            return { value: Math.round(b / 1000).toString(), unit: "KB/s" };
        return { value: Math.round(b).toString(), unit: "B/s" };
    }

    function secured(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown;
    }

    function join(n) {
        if (n.known || !secured(n)) {
            n.connect();
            root.pending = null;
        } else {
            root.pending = root.pending === n ? null : n;
        }
    }

    Text {
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize + 1
        color: hover.hovered || popup.visible ? Theme.primary : root.kind === "none" ? Theme.dim : Theme.fg
        text: root.kind === "ethernet" ? "󰈀"
            : root.kind === "wifi" ? root.glyph(root.signal)
            : Networking.wifiEnabled ? "󰤯" : "󰤮"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton
            ? Quickshell.execDetached(["nm-connection-editor"])
            : popup.toggle()
    }

    Binding {
        when: root.wifi !== null
        target: root.wifi
        property: "scannerEnabled"
        value: popup.visible
    }

    Process {
        id: counters
        command: ["sh", "-c", "cat /sys/class/net/" + root.iface + "/statistics/rx_bytes /sys/class/net/" + root.iface + "/statistics/tx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [rx, tx] = this.text.trim().split("\n").map(Number);
                const t = Date.now();
                if (root.last) {
                    const dt = (t - root.last.t) / 1000;
                    root.down = root.down.concat([(rx - root.last.rx) / dt]).slice(-30);
                    root.up = root.up.concat([(tx - root.last.tx) / dt]).slice(-30);
                }
                root.last = { rx, tx, t };
            }
        }
    }

    Timer {
        interval: 2000
        running: popup.visible && root.iface !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: counters.running = true
    }

    Process {
        id: address
        command: ["sh", "-c", "ip -4 -o addr show dev " + root.iface + " | awk '{print $4}' | cut -d/ -f1 | head -1"]
        stdout: StdioCollector { onStreamFinished: root.ip = this.text.trim() }
    }

    BarPopup {
        id: popup
        chip: root
        chipHovered: hover.hovered
        hold: root.pending !== null

        onVisibleChanged: {
            root.pending = null;
            root.last = null;
            root.down = [];
            root.up = [];
            if (visible && root.iface !== "")
                address.running = true;
        }

        Hero {
            eyebrow: root.kind === "ethernet" ? "Ethernet" : "Wi-Fi"
            value: root.kind === "ethernet" ? root.iface
                : !Networking.wifiEnabled ? "Off"
                : root.active ? root.active.name : "Not connected"
            subtitle: root.kind === "wifi"
                ? "Signal " + root.signal + "% · " + (root.secured(root.active) ? "Secured" : "Open")
                : root.kind === "none" && Networking.wifiEnabled ? "Choose a network" : ""
            toggleVisible: root.wifi !== null
            checked: Networking.wifiEnabled
            onToggled: on => Networking.wifiEnabled = on
        }

        GridLayout {
            visible: root.kind !== "none"
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            StatTile {
                label: "Download"
                value: root.rate(root.down[root.down.length - 1] ?? 0).value
                unit: root.rate(root.down[root.down.length - 1] ?? 0).unit
                Sparkline {
                    values: root.down
                    implicitHeight: 26
                }
            }
            StatTile {
                label: "Upload"
                value: root.rate(root.up[root.up.length - 1] ?? 0).value
                unit: root.rate(root.up[root.up.length - 1] ?? 0).unit
                Sparkline {
                    values: root.up
                    color: Theme.tertiary
                    implicitHeight: 26
                }
            }
        }

        Section {
            visible: root.kind !== "none"
            title: "Details"
            ListRow {
                implicitHeight: 30
                icon: "󰩟"
                title: "IP address"
                trailing: root.ip
                onClicked: Quickshell.execDetached(["wl-copy", root.ip])
            }
            ListRow {
                implicitHeight: 30
                icon: "󰛳"
                title: "Interface"
                trailing: root.iface
            }
        }

        Section {
            visible: Networking.wifiEnabled && root.networks.length > 0
            title: "Networks"

            Repeater {
                model: root.networks.slice(0, 8)
                ColumnLayout {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    ListRow {
                        icon: root.glyph(Math.round(entry.modelData.signalStrength * 100))
                        title: entry.modelData.name
                        subtitle: entry.modelData.stateChanging ? "Connecting…"
                            : entry.modelData.known ? "Saved"
                            : root.secured(entry.modelData) ? "Secured" : "Open"
                        trailing: root.secured(entry.modelData) ? "󰌾" : ""
                        onClicked: root.join(entry.modelData)
                    }

                    TextField {
                        visible: root.pending === entry.modelData
                        Layout.fillWidth: true
                        placeholderText: "Password"
                        echoMode: TextInput.Password
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        background: Rectangle {
                            radius: 8
                            color: Theme.surface_container_high
                            border.width: 1
                            border.color: Theme.primary
                        }
                        onVisibleChanged: if (visible) forceActiveFocus()
                        onAccepted: {
                            entry.modelData.connectWithPsk(text);
                            text = "";
                            root.pending = null;
                        }
                    }
                }
            }
        }

        Footer {
            text: "Network settings…"
            onClicked: {
                popup.visible = false;
                Quickshell.execDetached(["nm-connection-editor"]);
            }
        }
    }
}
