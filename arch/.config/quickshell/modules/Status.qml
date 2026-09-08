import Quickshell
import qs.theme
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 12

    Volume {}

    Text {
        visible: UPower.displayDevice.isLaptopBattery && UPower.onBattery
        color: UPower.displayDevice.percentage < 0.2 ? Theme.warn : Theme.fg
        font.pixelSize: Theme.fontSize
        text: Math.round(UPower.displayDevice.percentage * 100) + "%"
    }

    Clock {}
}
