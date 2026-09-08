pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property color island: Qt.rgba(0.141, 0.157, 0.231, 0.82)
    readonly property color islandBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color fg: "#c0caf5"
    readonly property color dim: "#565f89"
    readonly property color accent: "#7aa2f7"
    readonly property color warn: "#f7768e"

    readonly property int radius: 14
    readonly property int islandHeight: 32
    readonly property int fontSize: 12
}
