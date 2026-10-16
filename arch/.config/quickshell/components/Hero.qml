import QtQuick
import QtQuick.Layouts
import qs.theme

RowLayout {
    id: root

    property string eyebrow: ""
    property string value: ""
    property string unit: ""
    property string subtitle: ""
    property bool toggleVisible: false
    property bool checked: false
    signal toggled(bool on)

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            visible: text !== ""
            text: root.eyebrow.toUpperCase()
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 1
        }

        RowLayout {
            spacing: 4
            Text {
                Layout.maximumWidth: 270
                text: root.value
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }
            Text {
                visible: text !== ""
                Layout.alignment: Qt.AlignBaseline
                text: root.unit
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
        }

        Text {
            visible: text !== ""
            Layout.fillWidth: true
            text: root.subtitle
            elide: Text.ElideRight
            color: Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    Toggle {
        visible: root.toggleVisible
        Layout.alignment: Qt.AlignTop
        checked: root.checked
        onToggled: on => root.toggled(on)
    }
}
