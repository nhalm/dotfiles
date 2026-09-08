import Quickshell.Services.UPower
import QtQuick
import qs.theme

Item {
    id: root

    readonly property bool collapsed: !UPower.displayDevice.isLaptopBattery || !UPower.onBattery

    visible: !collapsed
    implicitWidth: collapsed ? 0 : label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: UPower.displayDevice.percentage < 0.2 ? Theme.warn : Theme.fg
        text: Math.round(UPower.displayDevice.percentage * 100) + "%"
    }
}
