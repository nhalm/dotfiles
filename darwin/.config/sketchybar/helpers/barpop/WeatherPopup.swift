import AppKit
import SwiftUI

struct WeatherPopup: View {
	@Environment(Weather.self) private var weather

	var body: some View {
		PopupCard(width: .wide) {
			if let f = weather.forecast {
				let condition = Condition(code: f.code)
				let today = f.days.first
				HeroHeader(
					eyebrow: weather.place ?? "Current location", eyebrowSymbol: "location.fill", value: deg(f.temp),
					subtitle: ([condition.name] + (today.map { ["H \(deg($0.high)) L \(deg($0.low))"] } ?? []))
						.joined(separator: " · "),
					backdrop: .sky(condition.sky, isNight: !f.isDay))
				Section("Next 12 hours", trailing: outlook(f)) {
					TrendChart(
						values: f.hours.map(\.temp), bars: f.hours.contains { $0.precip > 0 } ? f.hours.map(\.precip) : nil,
						xLabels: hourLabels(f), format: deg)
				}
				StatGrid(columns: 3) {
					StatTile(label: "Feels like", symbol: "thermometer.medium", value: deg(f.feels), detail: "Actual \(deg(f.temp))")
					StatTile(
						label: "Humidity", symbol: "humidity", value: "\(Int(f.humidity))", unit: "%",
						detail: "Dew pt \(deg(f.dewPoint))")
					StatTile(
						label: "Wind", symbol: "wind", value: "\(Int(f.wind.rounded()))", unit: "mph",
						detail: "Gusts \(Int(f.gusts.rounded()))"
					) { Compass(degrees: f.windFrom) }
				}
				Section("5-day") {
					let bounds = (f.days.map(\.low).min() ?? 0)...(f.days.map(\.high).max() ?? 1)
					ForEach(Array(f.days.enumerated()), id: \.offset) { i, day in
						ValueRow(
							i == 0 ? "Today" : format(day.date, "EEE", f.timeZone), symbol: Condition(code: day.code).symbol,
							note: day.precip >= 30 ? "\(Int(day.precip))%" : nil
						) {
							Meter(
								range: day.low...day.high, in: bounds, marker: i == 0 ? f.temp : nil,
								labels: (deg(day.low), deg(day.high)))
						}
					}
				}
				if let sun = daylight(f) {
					Section("Daylight", trailing: sun.trailing) {
						ArcProgress(
							progress: sun.progress, start: ("sunrise", format(sun.day.sunrise, "HH:mm", f.timeZone)),
							end: ("sunset", format(sun.day.sunset, "HH:mm", f.timeZone)))
					}
				}
			} else if let failure = weather.failure {
				EmptyState(
					symbol: "icloud.slash", title: "Weather unavailable", message: failure,
					action: ("Try again", { weather.refresh() }))
			} else {
				EmptyState(symbol: "location", title: "Finding the weather")
			}
			FooterLink("Open Weather", detail: weather.forecast.map { "Updated \(format($0.fetched, "HH:mm", .current))" }) {
				NSWorkspace.shared.openApplication(
					at: URL(fileURLWithPath: "/System/Applications/Weather.app"), configuration: .init())
			}
		}
	}

	private func deg(_ v: Double) -> String { "\(Int(v.rounded()))°" }

	private func format(_ date: Date, _ pattern: String, _ zone: TimeZone) -> String {
		let f = DateFormatter()
		f.dateFormat = pattern
		f.timeZone = zone
		return f.string(from: date)
	}

	private func hourLabels(_ f: Forecast) -> [Int: String] {
		var labels = [0: "Now"]
		for i in stride(from: 4, to: f.hours.count, by: 4) { labels[i] = format(f.hours[i].time, "HH", f.timeZone) }
		return labels
	}

	private func outlook(_ f: Forecast) -> String? {
		let hours = f.hours
		guard let first = hours.first else { return nil }
		let at = { (i: Int) in format(hours[i].time, "HH:mm", f.timeZone) }
		if first.precip >= 50 {
			return hours.firstIndex { $0.precip < 30 }.map { "Drying by \(at($0))" } ?? "Rain through the night"
		}
		if let wet = hours.firstIndex(where: { $0.precip >= 50 }) { return "Rain likely by \(at(wet))" }
		let temps = hours.map(\.temp)
		guard let hi = temps.indices.max(by: { temps[$0] < temps[$1] }),
			let lo = temps.indices.min(by: { temps[$0] < temps[$1] })
		else { return nil }
		return hi > 0 ? "High \(deg(temps[hi])) at \(at(hi))" : "Low \(deg(temps[lo])) at \(at(lo))"
	}

	// Today's sun, or tomorrow's once today's has set; progress only while up.
	private func daylight(_ f: Forecast) -> (day: Forecast.Day, progress: Double?, trailing: String)? {
		let now = Date()
		guard let today = f.days.first else { return nil }
		let day = now > today.sunset && f.days.count > 1 ? f.days[1] : today
		if now < day.sunrise { return (day, nil, "Sunrise in \(span(day.sunrise.timeIntervalSince(now)))") }
		let length = day.sunset.timeIntervalSince(day.sunrise)
		return (day, now.timeIntervalSince(day.sunrise) / length, span(length))
	}

	private func span(_ seconds: TimeInterval) -> String {
		let minutes = Int(seconds / 60)
		return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
	}
}
