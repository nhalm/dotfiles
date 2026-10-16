import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.components
import qs.services

Item {
    id: root

    readonly property var now: Weather.current
    readonly property var today: Weather.days[0] ?? null

    readonly property bool collapsed: now === null

    visible: !collapsed
    implicitWidth: collapsed ? 0 : label.implicitWidth
    implicitHeight: label.implicitHeight

    function deg(v) { return Math.round(v) + "°"; }

    function clock(ms) { return Qt.formatDateTime(new Date(ms), "HH:mm"); }

    function compass(d) { return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(d / 45) % 8]; }

    function outlook() {
        const h = Weather.hours;
        if (!h.length)
            return "";
        const wet = h.findIndex(x => x.precip >= 50);
        if (h[0].precip >= 50) {
            const dry = h.findIndex(x => x.precip < 30);
            return dry > 0 ? "Drying by " + clock(h[dry].time) : "Rain all evening";
        }
        if (wet > 0)
            return "Rain likely by " + clock(h[wet].time);
        const hi = h.reduce((a, x, i) => x.temp > h[a].temp ? i : a, 0);
        return "High " + deg(h[hi].temp) + " at " + clock(h[hi].time);
    }

    function span(ms) {
        const m = Math.round(ms / 60000);
        return Math.floor(m / 60) + "h " + m % 60 + "m";
    }

    Text {
        id: label
        anchors.centerIn: parent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: hover.hovered || popup.visible ? Theme.primary : Theme.fg
        text: root.now ? Weather.condition(root.now.code, root.now.isDay).glyph + " " + root.deg(root.now.temp) : ""
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        chip: root
        chipHovered: hover.hovered
        implicitWidth: 380

        onVisibleChanged: if (visible && Date.now() - Weather.fetched > 60000) Weather.refresh()

        Hero {
            eyebrow: Weather.place || "Current location"
            value: root.now ? root.deg(root.now.temp) : ""
            subtitle: root.now
                ? [Weather.condition(root.now.code, root.now.isDay).name]
                    .concat(root.today ? ["H " + root.deg(root.today.high) + "  L " + root.deg(root.today.low)] : [])
                    .join(" · ")
                : Weather.failure
        }

        Section {
            title: "Next 12 hours"
            trailing: root.outlook()

            Sparkline {
                values: Weather.hours.map(h => h.temp)
                fitRange: true
                implicitHeight: 44
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 14
                Repeater {
                    model: Weather.hours.length ? [0, 4, 8, 12].filter(i => i < Weather.hours.length) : []
                    Text {
                        required property int modelData
                        x: Math.min(parent.width - width, Math.max(0, modelData / (Weather.hours.length - 1) * parent.width - width / 2))
                        text: modelData === 0 ? "Now" : Qt.formatDateTime(new Date(Weather.hours[modelData].time), "HH")
                            + " " + root.deg(Weather.hours[modelData].temp)
                        color: Theme.dim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }

        GridLayout {
            visible: root.now !== null
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            StatTile {
                label: "Feels like"
                value: root.now ? root.deg(root.now.feels) : ""
                detail: root.now ? "Actual " + root.deg(root.now.temp) : ""
            }
            StatTile {
                label: "Humidity"
                value: root.now ? Math.round(root.now.humidity).toString() : ""
                unit: "%"
                detail: root.now ? "Dew pt " + root.deg(root.now.dewPoint) : ""
            }
            StatTile {
                label: "Wind"
                value: root.now ? Math.round(root.now.wind).toString() : ""
                unit: "mph"
                detail: root.now ? root.compass(root.now.windFrom) + " · gusts " + Math.round(root.now.gusts) : ""
            }
        }

        Section {
            title: "5-day"

            Repeater {
                model: Weather.days
                RowLayout {
                    id: day
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 26
                    spacing: 10

                    Text {
                        Layout.preferredWidth: 44
                        text: day.index === 0 ? "Today" : Qt.formatDateTime(new Date(day.modelData.date), "ddd")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.preferredWidth: 18
                        text: Weather.condition(day.modelData.code, true).glyph
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                    }
                    Text {
                        Layout.preferredWidth: 30
                        text: day.modelData.precip >= 30 ? Math.round(day.modelData.precip) + "%" : ""
                        color: Theme.tertiary
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                    Text {
                        Layout.preferredWidth: 28
                        horizontalAlignment: Text.AlignRight
                        text: root.deg(day.modelData.low)
                        color: Theme.dim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    Meter {
                        Layout.alignment: Qt.AlignVCenter
                        low: day.modelData.low
                        high: day.modelData.high
                        min: Math.min(...Weather.days.map(d => d.low))
                        max: Math.max(...Weather.days.map(d => d.high))
                        marker: day.index === 0 && root.now ? root.now.temp : NaN
                    }
                    Text {
                        Layout.preferredWidth: 28
                        text: root.deg(day.modelData.high)
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }

        Section {
            visible: root.today !== null
            title: "Daylight"
            trailing: root.today ? root.span(root.today.sunset - root.today.sunrise) : ""
            Text {
                text: root.today ? "\u{f059c} " + root.clock(root.today.sunrise) + "     \u{f059b} " + root.clock(root.today.sunset) : ""
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }

        Footer {
            text: "Refresh"
            detail: Weather.fetched ? "Updated " + root.clock(Weather.fetched) : ""
            onClicked: Weather.refresh()
        }
    }
}
