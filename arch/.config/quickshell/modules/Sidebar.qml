import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

PanelWindow {
    id: root

    property bool isOpen: false
    property real currentMargin: isOpen ? 0 : -470

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore
    implicitWidth: 420
    color: "transparent"
    visible: isOpen || slide.running

    anchors { right: true; top: true; bottom: true }
    margins { top: 52; bottom: 0; right: root.currentMargin }

    Behavior on currentMargin {
        NumberAnimation { id: slide; duration: 350; easing.type: Easing.OutQuint }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.isOpen
        onCleared: root.isOpen = false
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.isOpen = false
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void { root.isOpen = !root.isOpen; }
        function open(): void { root.isOpen = true; }
        function close(): void { root.isOpen = false; }
    }

    function run(cmd) {
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.primary
        opacity: 0.3
    }

    component SectionLabel: Text {
        color: Theme.primary
        font.family: Theme.fontFamily
        font.pixelSize: 16
    }

    component PillButton: Button {
        Layout.fillWidth: true
        background: Rectangle {
            color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
            border.color: Theme.primary
            border.width: 1
            radius: 10
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Text {
            text: parent.text
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: Theme.primary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            padding: 8
        }
    }

    component ToggleSwitch: Switch {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 48
        implicitHeight: 26
        indicator: Rectangle {
            implicitWidth: 48
            implicitHeight: 26
            radius: 13
            color: parent.checked ? Theme.primary : Theme.background
            border.color: Theme.primary
            border.width: 1
            Rectangle {
                x: parent.parent.checked ? parent.width - width - 2 : 2
                y: 2
                implicitWidth: 22
                implicitHeight: 22
                radius: 11
                color: parent.parent.checked ? Theme.background : Theme.primary
                Behavior on x { NumberAnimation { duration: 150 } }
            }
        }
    }

    component GlyphButton: Button {
        property string glyph: ""
        implicitWidth: 30
        implicitHeight: 30
        background: Rectangle {
            radius: 8
            color: parent.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Text {
            text: parent.glyph
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component LabeledSlider: RowLayout {
        property string glyph: ""
        property alias value: slider.value
        property alias from: slider.from
        signal moved(real v)

        Layout.fillWidth: true
        spacing: 14

        Text {
            text: parent.glyph
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 18
            Layout.alignment: Qt.AlignVCenter
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: 0
            to: 100
            onMoved: parent.moved(value)

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                implicitHeight: 6
                height: implicitHeight
                radius: 3
                color: Theme.background
                border.color: Theme.primary
                border.width: 1

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: Theme.primary
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                implicitWidth: 16
                implicitHeight: 16
                radius: 8
                color: slider.pressed ? Theme.background : Theme.primary
                border.color: Theme.primary
                border.width: 1
            }
        }
    }

    component ToggleRow: RowLayout {
        property string label: ""
        property alias checked: sw.checked
        signal toggled(bool on)

        Layout.fillWidth: true

        SectionLabel { text: parent.label }
        Item { Layout.fillWidth: true }
        ToggleSwitch {
            id: sw
            onClicked: parent.toggled(checked)
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 20

        Rectangle {
            id: frame
            anchors.fill: parent
            radius: 12
            opacity: 0.97

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Theme.primary }
                GradientStop { position: 1.0; color: Theme.secondary }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: parent.radius - 2
                color: Theme.background
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                GlyphButton {
                    glyph: "󰔎"
                    onClicked: root.run(Quickshell.env("HOME") + "/.local/scripts/theme-mode.sh")
                }
                GlyphButton {
                    glyph: "󰈊"
                    onClicked: { root.isOpen = false; root.run("hyprpicker -a"); }
                }
                GlyphButton {
                    glyph: "󰄀"
                    onClicked: { root.isOpen = false; root.run("hyprshot -m region -o ~/Pictures/Screenshots"); }
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: UPower.displayDevice.isLaptopBattery
                    color: Theme.on_background
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                }
            }

            Divider {}

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                PillButton {
                    text: "Wallpaper"
                    onClicked: { root.isOpen = false; root.run(Quickshell.env("HOME") + "/.local/scripts/wallpaper.sh"); }
                }
                PillButton {
                    text: "Displays"
                    onClicked: { root.isOpen = false; root.run("nwg-displays"); }
                }
            }

            Divider {}

            ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: body.implicitHeight
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Theme.primary
                        opacity: parent.pressed ? 1.0 : 0.4
                    }
                }

                ColumnLayout {
                    id: body
                    width: scroll.width
                    spacing: 18

                    LabeledSlider {
                        id: volume
                        glyph: "󰕾"
                        onMoved: v => root.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.round(v) + "%")

                        Process {
                            running: root.isOpen
                            command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'"]
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    const v = parseInt(this.text.trim());
                                    if (!isNaN(v)) volume.value = v;
                                }
                            }
                        }
                    }

                    LabeledSlider {
                        id: brightness
                        glyph: "󰃠"
                        from: 5
                        onMoved: v => root.run("brightnessctl set " + Math.round(v) + "%")

                        Process {
                            running: root.isOpen
                            command: ["bash", "-c", "brightnessctl -m | awk -F, '{gsub(\"%\",\"\",$4); print $4}'"]
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    const v = parseInt(this.text.trim());
                                    if (!isNaN(v)) brightness.value = Math.max(5, v);
                                }
                            }
                        }
                    }

                    Divider { Layout.topMargin: 4; Layout.bottomMargin: 4 }

                    ToggleRow {
                        id: wifiRow
                        label: "Wi-Fi"
                        onToggled: on => root.run("nmcli radio wifi " + (on ? "on" : "off"))

                        Process {
                            id: wifiProc
                            command: ["bash", "-c", "nmcli -t radio wifi"]
                            stdout: StdioCollector {
                                onStreamFinished: wifiRow.checked = this.text.trim() === "enabled"
                            }
                        }
                        Timer {
                            interval: 2000
                            repeat: true
                            running: root.isOpen
                            triggeredOnStart: true
                            onTriggered: wifiProc.running = true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            color: Theme.on_background
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            opacity: 0.8
                            elide: Text.ElideRight
                            text: netName.value
                        }
                        GlyphButton {
                            glyph: "󰒓"
                            onClicked: { root.isOpen = false; root.run("nm-connection-editor"); }
                        }
                    }

                    QtObject { id: netName; property string value: "" }

                    Process {
                        id: netProc
                        command: ["bash", "-c", "nmcli -t -f NAME connection show --active | head -1"]
                        stdout: StdioCollector {
                            onStreamFinished: netName.value = this.text.trim() || "Not connected"
                        }
                    }
                    Timer {
                        interval: 5000
                        repeat: true
                        running: root.isOpen
                        triggeredOnStart: true
                        onTriggered: netProc.running = true
                    }

                    ToggleRow {
                        id: btRow
                        label: "Bluetooth"
                        onToggled: on => root.run("bluetoothctl power " + (on ? "on" : "off"))

                        Process {
                            id: btProc
                            command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 1 || echo 0"]
                            stdout: StdioCollector {
                                onStreamFinished: btRow.checked = this.text.trim() === "1"
                            }
                        }
                        Timer {
                            interval: 2000
                            repeat: true
                            running: root.isOpen
                            triggeredOnStart: true
                            onTriggered: btProc.running = true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            color: Theme.on_background
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            opacity: 0.8
                            elide: Text.ElideRight
                            text: btName.value
                        }
                        GlyphButton {
                            glyph: "󰒓"
                            onClicked: { root.isOpen = false; root.run("blueman-manager"); }
                        }
                    }

                    QtObject { id: btName; property string value: "" }

                    Process {
                        id: btDevProc
                        command: ["bash", "-c", "bluetoothctl devices Connected | sed 's/^Device [^ ]* //' | paste -sd', ' -"]
                        stdout: StdioCollector {
                            onStreamFinished: btName.value = this.text.trim() || "No devices"
                        }
                    }
                    Timer {
                        interval: 5000
                        repeat: true
                        running: root.isOpen
                        triggeredOnStart: true
                        onTriggered: btDevProc.running = true
                    }

                    Divider { Layout.topMargin: 4; Layout.bottomMargin: 4 }

                    ToggleRow {
                        id: sunsetRow
                        label: "Blue Light Filter"
                        onToggled: on => root.run(on
                            ? "pgrep -x hyprsunset >/dev/null || setsid -f hyprsunset -t 4000 >/dev/null 2>&1"
                            : "pkill -x hyprsunset")

                        Process {
                            id: sunsetProc
                            command: ["bash", "-c", "pgrep -x hyprsunset >/dev/null && echo 1 || echo 0"]
                            stdout: StdioCollector {
                                onStreamFinished: sunsetRow.checked = this.text.trim() === "1"
                            }
                        }
                        Timer {
                            interval: 1000
                            repeat: true
                            running: root.isOpen
                            triggeredOnStart: true
                            onTriggered: sunsetProc.running = true
                        }
                    }

                    ToggleRow {
                        id: idleRow
                        label: "Idle & Lock"
                        onToggled: on => root.run(on
                            ? "pgrep -x hypridle >/dev/null || setsid -f hypridle >/dev/null 2>&1"
                            : "pkill -x hypridle")

                        Process {
                            id: idleProc
                            command: ["bash", "-c", "pgrep -x hypridle >/dev/null && echo 1 || echo 0"]
                            stdout: StdioCollector {
                                onStreamFinished: idleRow.checked = this.text.trim() === "1"
                            }
                        }
                        Timer {
                            interval: 2000
                            repeat: true
                            running: root.isOpen
                            triggeredOnStart: true
                            onTriggered: idleProc.running = true
                        }
                    }

                    ToggleRow {
                        id: dndRow
                        label: "Do Not Disturb"
                        onToggled: on => root.run("swaync-client -d -sw")

                        Process {
                            id: dndProc
                            command: ["bash", "-c", "swaync-client -D"]
                            stdout: StdioCollector {
                                onStreamFinished: dndRow.checked = this.text.trim() === "true"
                            }
                        }
                        Timer {
                            interval: 2000
                            repeat: true
                            running: root.isOpen
                            triggeredOnStart: true
                            onTriggered: dndProc.running = true
                        }
                    }

                    Divider {
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                        visible: Mpris.players.values.length > 0
                    }

                    Repeater {
                        model: Mpris.players.values

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 96
                            radius: 10
                            color: "transparent"
                            border.color: Theme.primary
                            border.width: 1
                            clip: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 14

                                Rectangle {
                                    implicitWidth: 72
                                    implicitHeight: 72
                                    radius: 8
                                    color: "transparent"
                                    border.color: Theme.primary
                                    border.width: 1
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.trackArtUrl ?? ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: (modelData.trackArtUrl ?? "") !== ""
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰝚"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 28
                                        color: Theme.primary
                                        visible: (modelData.trackArtUrl ?? "") === ""
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.trackTitle || modelData.identity || "Nothing playing"
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.trackArtist || "Unknown artist"
                                        color: Theme.on_background
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        opacity: 0.8
                                        elide: Text.ElideRight
                                    }

                                    Item { Layout.fillHeight: true }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Item { Layout.fillWidth: true }
                                        GlyphButton { glyph: "󰒮"; onClicked: modelData.previous() }
                                        GlyphButton {
                                            glyph: modelData.isPlaying ? "󰏤" : "󰐊"
                                            onClicked: modelData.togglePlaying()
                                        }
                                        GlyphButton { glyph: "󰒭"; onClicked: modelData.next() }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
