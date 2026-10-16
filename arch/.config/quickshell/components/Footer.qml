import QtQuick
import QtQuick.Layouts
import qs.theme

ColumnLayout {
    id: root

    property string text: ""
    property string detail: ""
    signal clicked()

    Layout.fillWidth: true
    spacing: 8

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.islandBorder
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.text
            color: link.hovered ? Theme.primary : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 12
            HoverHandler { id: link; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.clicked() }
        }
        Text {
            visible: text !== ""
            text: root.detail
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
