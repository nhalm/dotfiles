import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import qs.theme

Item {
    id: root

    property var chosen: null

    readonly property var barWindow: QsWindow.window
    readonly property var barContent: QsWindow.contentItem

    readonly property var players: Mpris.players.values
    readonly property var player: {
        if (chosen && players.indexOf(chosen) >= 0)
            return chosen;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }

    readonly property bool collapsed: player === null
        || ((player.trackTitle ?? "") === "" && (player.identity ?? "") === "")

    // A browser reports itself as the browser, so the site is the useful label.
    readonly property var sites: ({
        "youtube.com": "YouTube",
        "music.youtube.com": "YouTube Music",
        "open.spotify.com": "Spotify",
        "soundcloud.com": "SoundCloud",
        "twitch.tv": "Twitch",
        "netflix.com": "Netflix",
        "vimeo.com": "Vimeo",
        "bandcamp.com": "Bandcamp",
        "x.com": "X",
        "twitter.com": "X"
    })

    function sourceName(p) {
        if (!p)
            return "";

        const url = p.metadata?.["xesam:url"] ?? "";
        const match = /^https?:\/\/([^\/:]+)/.exec(url);

        if (match) {
            const host = match[1].replace(/^(www|m)\./, "");
            if (root.sites[host])
                return root.sites[host];

            const parts = host.split(".");
            const name = parts.length > 2 ? parts[parts.length - 2] : parts[0];
            return name.charAt(0).toUpperCase() + name.slice(1);
        }

        return p.identity || "Media";
    }

    component Control: Rectangle {
        id: ctl

        required property string glyph
        property bool active: true
        property int size: 30

        signal activated

        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: mouse.containsMouse && ctl.active ? Theme.surface_container_high : "transparent"
        opacity: ctl.active ? 1 : 0.35

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: ctl.glyph
            font.family: Theme.fontFamily
            font.pixelSize: ctl.size >= 38 ? 19 : 15
            color: Theme.on_surface
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (ctl.active) ctl.activated()
        }
    }

    visible: !collapsed
    implicitWidth: collapsed ? 0 : label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: hover.hovered || popup.visible ? Theme.primary : Theme.fg
        text: root.player ? (root.player.isPlaying ? "󰎇 " : "󰏤 ") + root.sourceName(root.player) : ""

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    HoverHandler { id: hover }

    IpcHandler {
        target: "media"
        function toggle(): void { popup.visible = !popup.visible && !root.collapsed; }
        function close(): void { popup.visible = false; }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (root.player?.canTogglePlaying)
                    root.player.togglePlaying();
                return;
            }
            popup.visible = !popup.visible;
        }
    }

    // Position only ticks while something is reading it.
    Timer {
        running: popup.visible && (root.player?.positionSupported ?? false)
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    PopupWindow {
        id: popup

        parentWindow: root.barWindow

        // Centred under the module, clamped to the bar. mapToItem does not
        // re-evaluate on an ancestor's layout change, so it is taken each time
        // the popup opens.
        onVisibleChanged: {
            if (!visible)
                return;
            const origin = root.mapToItem(root.barContent, 0, root.height);
            const centred = origin.x + root.width / 2 - implicitWidth / 2;
            relativeX = Math.round(Math.max(8,
                Math.min(centred, root.barWindow.width - implicitWidth - 8)));
            relativeY = Math.round(origin.y + 8);
        }

        implicitWidth: 380
        implicitHeight: card.implicitHeight
        color: "transparent"
        grabFocus: false

        // grabFocus makes the popup a toplevel that cannot attach to a layer
        // surface, so the grab is done by hand.
        HyprlandFocusGrab {
            windows: [popup]
            active: popup.visible
            onCleared: popup.visible = false
        }

        property real shown: visible ? 1 : 0

        Behavior on shown {
            NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
        }

        Rectangle {
            id: card

            width: parent.width
            implicitHeight: body.implicitHeight + 28
            y: (1 - popup.shown) * -10
            opacity: popup.shown

            radius: Theme.radius
            color: Theme.island
            border.width: 1
            border.color: Theme.islandBorder

            function fmt(us) {
                if (!us || us <= 0)
                    return "0:00";
                const total = Math.floor(us / 1000000);
                const mins = Math.floor(total / 60);
                const secs = total % 60;
                return mins + ":" + (secs < 10 ? "0" : "") + secs;
            }

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: 60
                        implicitHeight: 60
                        radius: 8
                        color: Theme.surface_container_high
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            visible: (root.player?.trackArtUrl ?? "") !== ""
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            font.family: Theme.fontFamily
                            font.pixelSize: 24
                            color: Theme.primary
                            visible: (root.player?.trackArtUrl ?? "") === ""
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.sourceName(root.player)
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.player?.trackTitle || "Nothing playing"
                            color: Theme.on_surface
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: (root.player?.trackArtist ?? "") !== ""
                            text: root.player?.trackArtist ?? ""
                            color: Theme.on_surface_variant
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            opacity: 0.85
                            elide: Text.ElideRight
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: (root.player?.lengthSupported ?? false) && (root.player?.length ?? 0) > 0
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 3
                        radius: 2
                        color: Theme.surface_container_high

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1,
                                (root.player?.position ?? 0) / (root.player?.length ?? 1)))
                            height: parent.height
                            radius: 2
                            color: Theme.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: card.fmt(root.player?.position ?? 0)
                            color: Theme.on_surface_variant
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            opacity: 0.7
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: card.fmt(root.player?.length ?? 0)
                            color: Theme.on_surface_variant
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            opacity: 0.7
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Item { Layout.fillWidth: true }

                    Control {
                        glyph: "󰒮"
                        active: root.player?.canGoPrevious ?? false
                        onActivated: root.player.previous()
                    }

                    Control {
                        glyph: root.player?.isPlaying ? "󰏤" : "󰐊"
                        size: 38
                        active: root.player?.canTogglePlaying ?? false
                        onActivated: root.player.togglePlaying()
                    }

                    Control {
                        glyph: "󰒭"
                        active: root.player?.canGoNext ?? false
                        onActivated: root.player.next()
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.players.length > 1
                    spacing: 6

                    Repeater {
                        model: root.players

                        Rectangle {
                            required property var modelData

                            readonly property bool active: root.player === modelData

                            radius: 6
                            color: active ? Theme.primary_container : Theme.surface_container_high
                            border.width: 1
                            border.color: active ? Theme.primary : Theme.outline_variant
                            implicitWidth: chip.implicitWidth + 14
                            implicitHeight: chip.implicitHeight + 8

                            Text {
                                id: chip
                                anchors.centerIn: parent
                                text: root.sourceName(modelData)
                                color: Theme.on_surface
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.chosen = modelData
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
