pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property string place: ""
    property string coords: ""
    property double located: 0
    property var current: null
    property var hours: []
    property var days: []
    property double fetched: 0
    property string failure: ""

    readonly property var conditions: [
        [[0], "Clear", "\u{f0599}", "\u{f0594}"],
        [[1, 2], "Partly cloudy", "\u{f0595}", "\u{f0f31}"],
        [[3], "Overcast", "\u{f0590}", "\u{f0590}"],
        [[45, 48], "Fog", "\u{f0591}", "\u{f0591}"],
        [[51, 53, 55, 56, 57], "Drizzle", "\u{f0597}", "\u{f0597}"],
        [[61, 63, 66, 80, 81], "Rain", "\u{f0597}", "\u{f0597}"],
        [[65, 67, 82], "Heavy rain", "\u{f0596}", "\u{f0596}"],
        [[71, 73, 75, 77, 85, 86], "Snow", "\u{f0598}", "\u{f0598}"],
        [[95, 96, 99], "Thunderstorm", "\u{f0593}", "\u{f0593}"]
    ]

    function condition(code, isDay) {
        const c = root.conditions.find(e => e[0].includes(code)) ?? root.conditions[2];
        return { name: c[1], glyph: isDay === false ? c[3] : c[2] };
    }

    function get(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let body = null;
            if (xhr.status === 200)
                try { body = JSON.parse(xhr.responseText); } catch (e) {}
            done(body);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function refresh() {
        if (root.coords === "" || Date.now() - root.located > 1800000) {
            root.get("https://ipinfo.io/json", r => {
                if (r?.loc) {
                    root.coords = r.loc;
                    root.place = [r.city, r.region].filter(s => s).join(", ");
                    root.located = Date.now();
                }
                root.fetch();
            });
            return;
        }
        root.fetch();
    }

    function fetch() {
        if (root.coords === "") {
            root.failure = "Location unavailable";
            return;
        }
        const [lat, lon] = root.coords.split(",");
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,dew_point_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m,wind_gusts_10m"
            + "&hourly=temperature_2m,precipitation_probability"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + "&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto&timeformat=unixtime&forecast_days=5&forecast_hours=13";
        root.get(url, r => {
            if (!r?.current) {
                root.failure = "Open-Meteo didn't answer";
                return;
            }
            const c = r.current;
            root.current = {
                temp: c.temperature_2m, feels: c.apparent_temperature, humidity: c.relative_humidity_2m,
                dewPoint: c.dew_point_2m, code: c.weather_code, isDay: c.is_day === 1,
                wind: c.wind_speed_10m, windFrom: c.wind_direction_10m, gusts: c.wind_gusts_10m
            };
            root.hours = r.hourly.time.map((t, i) => ({
                time: t * 1000, temp: r.hourly.temperature_2m[i] ?? 0, precip: r.hourly.precipitation_probability[i] ?? 0
            }));
            const d = r.daily;
            root.days = d.time.map((t, i) => ({
                date: t * 1000, code: d.weather_code[i], high: d.temperature_2m_max[i], low: d.temperature_2m_min[i],
                precip: d.precipitation_probability_max[i] ?? 0, sunrise: d.sunrise[i] * 1000, sunset: d.sunset[i] * 1000
            }));
            root.fetched = Date.now();
            root.failure = "";
        });
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
