import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.theme

Item {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Text {
        id: label
        color: hover.hovered ? Theme.accent : Theme.fg
        font.pixelSize: Theme.fontSize
        text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.visible = !popup.visible
    }

    PanelWindow {
        id: popup
        visible: false
        color: "transparent"
        implicitWidth: 300
        implicitHeight: 320
        anchors { top: true }
        margins { top: 48 }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.island
            border.width: 1
            border.color: Theme.islandBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: Theme.fg
                    font.pixelSize: 16
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                }

                DayOfWeekRow {
                    Layout.fillWidth: true
                    delegate: Text {
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.dim
                        font.pixelSize: 11
                        text: shortName
                    }
                }

                MonthGrid {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    month: clock.date.getMonth()
                    year: clock.date.getFullYear()

                    delegate: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        font.bold: model.today
                        opacity: model.month === grid.month ? 1 : 0.3
                        color: model.today ? Theme.accent : Theme.fg
                        text: model.day
                    }
                }
            }
        }
    }
}
