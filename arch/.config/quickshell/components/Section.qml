import QtQuick
import QtQuick.Layouts
import qs.theme

ColumnLayout {
    id: root

    property string title: ""
    property string trailing: ""
    default property alias content: inner.data

    Layout.fillWidth: true
    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
        Text {
            visible: text !== ""
            text: root.trailing
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    ColumnLayout {
        id: inner
        Layout.fillWidth: true
        spacing: 2
    }
}
