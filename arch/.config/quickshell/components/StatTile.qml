import QtQuick
import QtQuick.Layouts
import qs.theme

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string unit: ""
    property string detail: ""
    default property alias footer: col.data

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: col.implicitHeight + 20
    radius: 10
    color: Theme.surface_container_high

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 10
        spacing: 1

        Text {
            text: root.label
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
        RowLayout {
            spacing: 3
            Text {
                text: root.value
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
            Text {
                visible: text !== ""
                Layout.alignment: Qt.AlignBaseline
                text: root.unit
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
        Text {
            visible: text !== ""
            Layout.fillWidth: true
            text: root.detail
            elide: Text.ElideRight
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
