import QtQuick
import QtQuick.Layouts
import qs.theme

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool selected: false
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 40
    radius: 8
    color: hover.hovered ? Theme.surface_container_high : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10

        Text {
            Layout.preferredWidth: 20
            horizontalAlignment: Text.AlignHCenter
            text: root.icon
            color: root.selected ? Theme.primary : Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                color: root.selected ? Theme.primary : Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: root.subtitle
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
        Text {
            visible: text !== ""
            text: root.trailing
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
