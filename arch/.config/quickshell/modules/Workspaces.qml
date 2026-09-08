import qs.theme
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property string screenName: ""
    spacing: 4

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            required property var modelData
            visible: modelData.monitor?.name === root.screenName
                     && (modelData.focused || modelData.lastIpcObject?.windows > 0)
            implicitWidth: !visible ? 0 : (modelData.focused ? 30 : 22)
            implicitHeight: 22
            radius: modelData.focused ? 9 : 7
            color: modelData.focused
                   ? Qt.rgba(0.478, 0.635, 0.968, 0.35)
                   : (hover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")

            Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            Text {
                anchors.centerIn: parent
                text: modelData.id
                font.pixelSize: 11
                color: modelData.focused ? Theme.fg : Theme.dim
            }

            HoverHandler { id: hover }

            MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData.id + " })")
            }
        }
    }
}
