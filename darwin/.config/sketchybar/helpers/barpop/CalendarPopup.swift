import AppKit
import SwiftUI

struct CalendarPopup: View {
	@Environment(Agenda.self) private var agenda
	@Environment(Presentation.self) private var presentation

	private static let clocks = [
		("NYC", "America/New_York"), ("SF", "America/Los_Angeles"), ("UTC", "UTC"),
	]

	var body: some View {
		TimelineView(.everyMinute) { context in
			let now = context.date
			PopupCard(width: .wide) {
				HeroHeader(
					eyebrow: format(now, "EEEEMMMMd"), value: format(now, "HHmm"),
					subtitle:
						"Week \(Calendar(identifier: .iso8601).component(.weekOfYear, from: now)) · Day \(Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0)"
				)
				Section(format(agenda.month, "MMMMy")) {
					MonthGrid(month: agenda.month, today: now, selected: agenda.selected, marked: agenda.marked) {
						agenda.select($0)
					}
				} trailing: {
					IconButton(symbol: "chevron.left", label: "Previous month") { agenda.showMonth(-1) }
					IconButton(symbol: "chevron.right", label: "Next month") { agenda.showMonth(1) }
				}
				events(now)
				Section("World clocks") {
					StatGrid(columns: 3) {
						ForEach(Self.clocks, id: \.1) { city, id in
							let zone = TimeZone(identifier: id) ?? .current
							StatTile(label: city, value: format(now, "HHmm", zone), detail: offset(zone, now)) {
								ClockFace(date: now, timeZone: zone)
							}
						}
					}
				}
				FooterLink("Open Calendar") {
					NSWorkspace.shared.openApplication(
						at: URL(fileURLWithPath: "/System/Applications/Calendar.app"), configuration: .init())
				}
			}
		}
	}

	// Today lists what's left, topped up with tomorrow; another day lists all of it.
	@ViewBuilder private func events(_ now: Date) -> some View {
		let isToday = Calendar.current.isDate(agenda.selected, inSameDayAs: now)
		let label = isToday ? "Up next" : format(agenda.selected, "EEEEMMMMd")
		if agenda.access != .granted {
			Section(label) {
				EmptyState(
					symbol: "calendar.badge.lock", title: "No calendar access",
					message: "Allow barpop to show your events.", action: ("Allow access", { agenda.allowAccess() }))
			}
		} else {
			let left = isToday ? agenda.events.filter { $0.end > now } : agenda.events
			let rows = left.map { (event: $0, tomorrow: false) }
				+ (isToday ? agenda.tomorrow.prefix(max(4 - left.count, 0)).map { (event: $0, tomorrow: true) } : [])
			let count = agenda.events.count
			Section(label, trailing: count == 0 ? nil : (isToday ? "\(count) today" : "\(count) event\(count == 1 ? "" : "s")")) {
				if rows.isEmpty {
					EmptyState(symbol: "calendar", title: isToday ? (count > 0 ? "Nothing else today" : "Nothing today") : "No events")
				}
				ForEach(rows, id: \.event.id) { row in
					StripItem(
						title: row.event.title, subtitle: subtitle(row.event, tomorrow: row.tomorrow),
						tone: row.event.isWork ? .accent : .alt, chip: soon(row.event, now)
					) {
						agenda.show(row.event)
						presentation.close()
					}
				}
			}
		}
	}

	private func subtitle(_ e: Event, tomorrow: Bool) -> String {
		let time = e.isAllDay ? "All day" : "\(format(e.start, "HHmm")) – \(format(e.end, "HHmm"))"
		return ((tomorrow ? ["Tomorrow"] : []) + [time] + (e.location.map { [$0] } ?? [])).joined(separator: " · ")
	}

	private func soon(_ e: Event, _ now: Date) -> String? {
		guard !e.isAllDay else { return nil }
		if e.start <= now && e.end > now { return "Now" }
		let minutes = Int(e.start.timeIntervalSince(now) / 60) + 1
		return e.start > now && minutes <= 60 ? "in \(minutes) min" : nil
	}

	private func offset(_ zone: TimeZone, _ now: Date) -> String {
		let diff = zone.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)
		guard diff != 0 else { return "Local time" }
		let sign = diff > 0 ? "+" : "−"
		let hours = abs(diff) / 3600
		let minutes = abs(diff) % 3600 / 60
		return minutes == 0 ? "\(sign)\(hours) h" : "\(sign)\(hours):\(String(format: "%02d", minutes)) h"
	}

	private func format(_ date: Date, _ template: String, _ zone: TimeZone = .current) -> String {
		let f = DateFormatter()
		f.setLocalizedDateFormatFromTemplate(template)
		f.timeZone = zone
		return f.string(from: date)
	}
}
