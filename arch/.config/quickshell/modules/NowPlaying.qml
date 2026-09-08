import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.theme

Item {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property bool collapsed: player === null || (player.trackTitle ?? "") === ""

    visible: !collapsed
    implicitWidth: collapsed ? 0 : label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.fg
        elide: Text.ElideRight
        text: root.player ? (root.player.isPlaying ? "󰎇 " : "󰏤 ") + (root.player.trackTitle ?? "") : ""
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.player?.canTogglePlaying) root.player.togglePlaying()
    }
}
