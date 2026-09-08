pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.theme

Scope {
    id: root

    property bool isOpen: false
    property string query: ""
    property int index: 0

    // The carousel and the keyboard live on whichever monitor was focused when
    // the picker opened; the others only dim and show the backdrop.
    property string activeScreen: ""
    property bool committing: false

    readonly property var entries: {
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return Wallpapers.paths;
        return Wallpapers.paths.filter(p => Wallpapers.displayName(p).toLowerCase().includes(q));
    }

    readonly property string highlighted: entries[index] ?? ""

    function open(): void {
        Wallpapers.refresh();
        root.activeScreen = Hyprland.focusedMonitor?.name ?? "";
        root.query = "";
        root.resetIndex();
        root.isOpen = true;
    }

    function close(): void {
        root.isOpen = false;
    }

    function apply(): void {
        if (root.highlighted !== "") {
            root.committing = true;
            Wallpapers.set(root.highlighted);
        }
        root.isOpen = false;
    }

    function resetIndex(): void {
        const at = root.entries.indexOf(Wallpapers.current);
        root.index = root.query.trim() === "" && at >= 0 ? at : 0;
    }

    // Clamped rather than wrapped: the strip slides by position, so wrapping
    // from one end to the other would animate across the whole list.
    function step(delta: int): void {
        const n = root.entries.length;
        if (n > 0)
            root.index = Math.max(0, Math.min(n - 1, root.index + delta));
    }

    onEntriesChanged: resetIndex()
    onHighlightedChanged: if (root.isOpen) previewTimer.restart()

    onIsOpenChanged: {
        if (!root.isOpen) {
            previewTimer.stop();
            if (root.committing)
                Wallpapers.holdPreview();
            else
                Wallpapers.stopPreview();
            root.committing = false;
        } else {
            previewTimer.restart();
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.isOpen ? root.close() : root.open(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    Timer {
        id: previewTimer
        interval: 220
        onTriggered: {
            if (root.highlighted !== "")
                Wallpapers.previewColours(root.highlighted);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            readonly property bool active: modelData.name === root.activeScreen
            readonly property int itemWidth: Math.round(Math.min(400, width / 5.5))
            readonly property int itemHeight: Math.round(itemWidth / 16 * 9)
            readonly property int slotWidth: itemWidth + 40

            // Always odd so one item sits dead centre.
            readonly property int visibleItems: {
                const fits = Math.floor((width - 120) / slotWidth);
                return Math.max(1, fits % 2 === 0 ? fits - 1 : fits);
            }

            screen: modelData
            visible: root.isOpen
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: WlrLayershell.Ignore

            Image {
                id: backdrop
                anchors.fill: parent
                source: root.highlighted === "" ? "" : "file://" + root.highlighted
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: 1280
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: backdrop
                blurEnabled: true
                blur: 1.0
                blurMax: 56
                opacity: backdrop.status === Image.Ready ? 0.45 : 0

                Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.surface_container_lowest.r, Theme.surface_container_lowest.g, Theme.surface_container_lowest.b, 0.78)

                Behavior on color { ColorAnimation { duration: 250 } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            // Built on open so no previews are decoded while the picker is
            // closed, and so the search field starts empty and focused.
            Loader {
                anchors.centerIn: parent
                active: root.isOpen && win.active

                sourceComponent: Column {
                    spacing: 44

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 460
                        height: 48
                        radius: Theme.radius
                        color: Theme.island
                        border.width: 1
                        border.color: search.activeFocus ? Theme.primary : Theme.islandBorder

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 17
                        }

                        TextField {
                            id: search

                            anchors.fill: parent
                            anchors.leftMargin: searchIcon.width + 30
                            anchors.rightMargin: 18
                            verticalAlignment: Text.AlignVCenter
                            background: null
                            color: Theme.on_surface
                            placeholderText: root.entries.length + " wallpapers"
                            placeholderTextColor: Theme.outline
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.on_primary

                            text: root.query
                            onTextChanged: root.query = text

                            Component.onCompleted: forceActiveFocus()

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Left || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                    root.step(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                                    root.step(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.apply();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.close();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Laid out by hand rather than with PathView: PathView keeps a
                    // scroll offset that does not reliably follow currentIndex when
                    // the model arrives after the view is built.
                    Item {
                        id: strip

                        readonly property int reach: Math.floor(win.visibleItems / 2)

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(win.visibleItems, root.entries.length) * win.slotWidth
                        height: win.itemHeight + 90
                        clip: true

                        Repeater {
                            model: root.entries

                            delegate: Item {
                                id: item

                                required property string modelData
                                required property int index

                                readonly property int distance: index - root.index
                                readonly property bool selected: distance === 0
                                readonly property bool onStrip: Math.abs(distance) <= strip.reach

                                width: win.slotWidth
                                height: strip.height
                                x: (strip.width - width) / 2 + distance * win.slotWidth
                                z: selected ? 1 : 0
                                visible: Math.abs(distance) <= strip.reach + 1
                                scale: selected ? 1 : 0.72
                                opacity: onStrip ? (selected ? 1 : 0.45) : 0

                                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 240 } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        implicitWidth: win.itemWidth
                                        implicitHeight: win.itemHeight

                                        MultiEffect {
                                            anchors.fill: frame
                                            source: frame
                                            shadowEnabled: true
                                            shadowBlur: 1.0
                                            shadowVerticalOffset: 8
                                            shadowColor: Qt.rgba(0, 0, 0, 0.7)
                                            opacity: item.selected ? 1 : 0

                                            Behavior on opacity { NumberAnimation { duration: 240 } }
                                        }

                                        ClippingRectangle {
                                            id: frame

                                            anchors.fill: parent
                                            radius: Theme.radius + 4
                                            color: Theme.surface_container
                                            border.width: 3
                                            border.color: item.selected ? Theme.primary : "transparent"

                                            Behavior on border.color { ColorAnimation { duration: 200 } }

                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: 3
                                                source: "file://" + item.modelData
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                sourceSize.width: win.itemWidth * 2
                                            }
                                        }

                                        Rectangle {
                                            anchors.top: frame.top
                                            anchors.right: frame.right
                                            anchors.margins: 12
                                            width: 26
                                            height: 26
                                            radius: 13
                                            visible: item.modelData === Wallpapers.current
                                            color: Theme.primary

                                            Text {
                                                anchors.centerIn: parent
                                                text: ""
                                                color: Theme.on_primary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 14
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: win.itemWidth
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: Wallpapers.displayName(item.modelData)
                                        color: item.selected ? Theme.on_surface : Theme.on_surface_variant
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        font.bold: item.selected
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: item.onStrip
                                    onClicked: item.selected ? root.apply() : root.index = item.index
                                }
                            }
                        }

                        WheelHandler {
                            onWheel: event => root.step(event.angleDelta.y < 0 || event.angleDelta.x > 0 ? 1 : -1)
                        }
                    }


                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.entries.length === 0
                        text: root.query.trim() === "" ? "No wallpapers in " + Wallpapers.dir : "No match for \"" + root.query + "\""
                        color: Theme.outline
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "←/→ browse    ⏎ apply    esc cancel"
                        color: Theme.outline
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
