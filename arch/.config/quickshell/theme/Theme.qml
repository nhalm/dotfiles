pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    property color background: "#1f2335"
    property color error: "#f7768e"
    property color inverse_surface: "#c0caf5"
    property color on_background: "#c0caf5"
    property color on_error: "#1f2335"
    property color on_primary: "#1f2335"
    property color on_primary_container: "#c0caf5"
    property color on_secondary: "#1f2335"
    property color on_secondary_container: "#c0caf5"
    property color on_surface: "#c0caf5"
    property color on_surface_variant: "#a9b1d6"
    property color outline: "#565f89"
    property color outline_variant: "#414868"
    property color primary: "#7aa2f7"
    property color primary_container: "#3d59a1"
    property color secondary: "#bb9af7"
    property color secondary_container: "#414868"
    property color shadow: "#000000"
    property color surface: "#24283b"
    property color surface_bright: "#414868"
    property color surface_container: "#24283b"
    property color surface_container_high: "#292e42"
    property color surface_container_highest: "#3b4261"
    property color surface_container_low: "#1f2335"
    property color surface_container_lowest: "#1a1b26"
    property color surface_dim: "#1a1b26"
    property color surface_variant: "#414868"
    property color tertiary: "#7dcfff"

    readonly property color island: Qt.rgba(surface_container.r, surface_container.g, surface_container.b, 0.82)
    readonly property color islandBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color fg: on_surface
    readonly property color dim: outline
    readonly property color accent: primary
    readonly property color warn: error

    readonly property int radius: 14
    readonly property int islandHeight: 32
    readonly property int fontSize: 12

    property var reader: Process {
        id: proc
        command: ["cat", Quickshell.env("HOME") + "/.local/state/matugen/colors.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim();
                if (out === "")
                    return;
                try {
                    const colors = JSON.parse(out);
                    for (const key in colors)
                        if (root.hasOwnProperty(key) && key !== "objectName")
                            root[key] = colors[key];
                } catch (e) {
                    console.log("Theme: bad colors.json: " + e);
                }
            }
        }
    }

    function reloadTheme() {
        proc.running = false;
        proc.running = true;
    }

    Component.onCompleted: reloadTheme()
}
