import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import qs.theme

RowLayout {
    id: root
    spacing: 6

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int pct: sink?.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker { objects: [root.sink] }

    Text {
        font.pixelSize: Theme.fontSize
        color: root.muted ? Theme.dim : Theme.fg
        text: root.muted ? "󰝟" : (root.pct > 50 ? "󰕾" : "󰖀")
    }

    Text {
        font.pixelSize: Theme.fontSize
        color: root.muted ? Theme.dim : Theme.fg
        text: root.pct + "%"
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (!root.sink?.audio) return;
            if (mouse.button === Qt.RightButton)
                Quickshell.execDetached(["pavucontrol"]);
            else
                root.sink.audio.muted = !root.sink.audio.muted;
        }
        onWheel: wheel => {
            if (!root.sink?.audio) return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }
}
