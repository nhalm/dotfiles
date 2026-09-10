import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

PanelWindow {
    id: root

    property bool isOpen: false
    property int selected: 0

    // Workspaces that have windows, ordered normal-first then scratchpads,
    // each with its client list flattened for keyboard navigation.
    readonly property var groups: {
        const all = [...Hyprland.workspaces.values]
            .map(w => ({ ws: w, clients: [...w.toplevels.values] }))
            .filter(g => g.clients.length > 0);
        all.sort((a, b) => {
            const sa = a.ws.id < 0 ? 1 : 0;
            const sb = b.ws.id < 0 ? 1 : 0;
            return sa !== sb ? sa - sb : a.ws.id - b.ws.id;
        });
        return all;
    }

    readonly property var flat: groups.reduce((acc, g) => acc.concat(g.clients), [])

    visible: isOpen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: WlrLayershell.Ignore

    onIsOpenChanged: {
        if (!isOpen)
            return;
        const active = flat.findIndex(t => t.activated);
        selected = active >= 0 ? active : 0;
    }

    IpcHandler {
        target: "overview"
        function toggle(): void { root.isOpen = !root.isOpen; }
        function close(): void { root.isOpen = false; }
    }

    function step(delta) {
        if (root.flat.length === 0)
            return;
        root.selected = (root.selected + delta + root.flat.length) % root.flat.length;
    }

    // Up/down jump a whole workspace rather than a single tile.
    function stepGroup(delta) {
        if (root.flat.length === 0)
            return;
        const current = root.flat[root.selected];
        let index = root.groups.findIndex(g => g.clients.indexOf(current) >= 0);
        index = (index + delta + root.groups.length) % root.groups.length;
        root.selected = root.flat.indexOf(root.groups[index].clients[0]);
    }

    function activate() {
        const target = root.flat[root.selected];
        if (target)
            root.focusWindow(target.address);
    }

    function focusWindow(address) {
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })");
        root.isOpen = false;
    }

    Shortcut { sequence: "Escape"; onActivated: root.isOpen = false }
    Shortcut { sequences: ["Right", "L", "Tab"]; onActivated: root.step(1) }
    Shortcut { sequences: ["Left", "H", "Backtab"]; onActivated: root.step(-1) }
    Shortcut { sequences: ["Down", "J"]; onActivated: root.stepGroup(1) }
    Shortcut { sequences: ["Up", "K"]; onActivated: root.stepGroup(-1) }
    Shortcut { sequences: ["Return", "Enter"]; onActivated: root.activate() }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: root.isOpen = false
        }
    }

    ScrollView {
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, 1600)
        height: Math.min(parent.height - 120, column.implicitHeight + 40)
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 24

            Repeater {
                model: root.groups

                ColumnLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        spacing: 8

                        Text {
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                            text: modelData.ws.id < 0
                                ? (modelData.ws.name.replace("special:", "") + " (scratchpad)")
                                : "Workspace " + modelData.ws.id
                        }

                        Text {
                            color: Theme.on_surface_variant
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            opacity: 0.7
                            text: modelData.clients.length + (modelData.clients.length === 1 ? " window" : " windows")
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 14

                        Repeater {
                            model: modelData.clients

                            Rectangle {
                                id: tile
                                required property var modelData

                                readonly property bool current: root.flat[root.selected] === modelData

                                width: 300
                                height: 210
                                radius: 12
                                color: current || hover.hovered ? Theme.surface_container_high : Theme.surface_container
                                border.width: current ? 2 : 1
                                border.color: current
                                    ? Theme.primary
                                    : (modelData.activated ? Theme.secondary : Theme.outline_variant)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 8
                                        color: Theme.surface
                                        clip: true

                                        ScreencopyView {
                                            id: preview
                                            anchors.centerIn: parent
                                            captureSource: root.isOpen ? tile.modelData.wayland : null
                                            live: root.isOpen
                                            paintCursor: false
                                            constraintSize: Qt.size(parent.width, parent.height)
                                        }

                                        // Toplevel export needs a frame before it
                                        // has anything to show; until then, the class.
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !preview.hasContent
                                            color: Theme.on_surface_variant
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            opacity: 0.6
                                            text: tile.modelData.lastIpcObject?.class ?? "no preview"
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        color: Theme.on_surface
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: true
                                        elide: Text.ElideRight
                                        text: tile.modelData.title || "(untitled)"
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        color: Theme.on_surface_variant
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        opacity: 0.8
                                        elide: Text.ElideRight
                                        text: tile.modelData.lastIpcObject?.class ?? ""
                                    }
                                }

                                HoverHandler {
                                    id: hover
                                    onHoveredChanged: {
                                        if (hovered)
                                            root.selected = root.flat.indexOf(tile.modelData);
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.focusWindow(tile.modelData.address)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.groups.length === 0
                Layout.alignment: Qt.AlignHCenter
                color: Theme.on_surface_variant
                font.family: Theme.fontFamily
                font.pixelSize: 14
                text: "Nothing open"
            }
        }
    }
}
