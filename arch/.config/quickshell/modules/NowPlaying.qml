import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.theme

Text {
    id: root
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    visible: player !== null && text !== ""
    color: Theme.fg
    font.pixelSize: Theme.fontSize
    elide: Text.ElideRight
    maximumLineCount: 1
    text: player ? (player.isPlaying ? "󰎇 " : "󰏤 ") + (player.trackTitle ?? "") : ""

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.player?.canTogglePlaying) root.player.togglePlaying()
    }
}
