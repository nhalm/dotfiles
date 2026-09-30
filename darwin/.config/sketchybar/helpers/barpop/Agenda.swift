import AppKit
import EventKit
import Observation

struct Event: Identifiable, Sendable {
	let id: String
	let item: String
	let title: String
	let start: Date
	let end: Date
	let isAllDay: Bool
	let location: String?
	let isWork: Bool
}

// Events from EventKit for the month on show (as marks), the selected day
// and tomorrow. Declined events are left out.
@MainActor
@Observable
final class Agenda {
	enum Access { case unknown, granted, denied }

	private(set) var access: Access
	private(set) var month: Date
	private(set) var selected: Date
	private(set) var marked: Set<Date> = []
	private(set) var events: [Event] = []
	private(set) var tomorrow: [Event] = []

	@ObservationIgnored private let store = EKEventStore()
	@ObservationIgnored private var loading: Task<Void, Never>?

	init() {
		access = Self.status()
		let today = Calendar.current.startOfDay(for: Date())
		selected = today
		month = today
		NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) {
			[weak self] _ in MainActor.assumeIsolated { self?.reload() }
		}
		reload()
	}

	// Each opening starts on today; the first asks for access.
	func open() {
		let status = Self.status()
		if status == .granted && access != .granted { store.reset() }
		access = status
		if access == .unknown { requestAccess() }
		select(Date())
	}

	func select(_ day: Date) {
		selected = Calendar.current.startOfDay(for: day)
		month = selected
		reload()
	}

	func showMonth(_ offset: Int) {
		guard let m = Calendar.current.date(byAdding: .month, value: offset, to: month) else { return }
		month = m
		reload()
	}

	func allowAccess() {
		if access == .unknown {
			requestAccess()
		} else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
			NSWorkspace.shared.open(url)
		}
	}

	func show(_ event: Event) {
		guard let id = event.item.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
			let url = URL(string: "ical://ekevent/\(id)?method=show&options=more")
		else { return }
		NSWorkspace.shared.open(url)
	}

	private func requestAccess() {
		Task {
			let granted = (try? await store.requestFullAccessToEvents()) ?? false
			access = granted ? .granted : .denied
			reload()
		}
	}

	private func reload() {
		loading?.cancel()
		guard access == .granted else {
			(marked, events, tomorrow) = ([], [], [])
			return
		}
		let c = Calendar.current
		let grid = MonthGrid.days(in: month)
		guard let gridStart = grid.first, let gridEnd = grid.last.flatMap({ c.date(byAdding: .day, value: 1, to: $0) }),
			let dayEnd = c.date(byAdding: .day, value: 1, to: selected),
			let tomorrowStart = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: Date())),
			let tomorrowEnd = c.date(byAdding: .day, value: 1, to: tomorrowStart)
		else { return }
		// EventKit isn't annotated Sendable; fetching off the main thread is how Apple uses it.
		nonisolated(unsafe) let store = store
		let day = selected
		loading = Task {
			let result = await Task.detached {
				var marks = Set<Date>()
				for e in Self.fetch(store, gridStart, gridEnd) {
					var d = max(c.startOfDay(for: e.start), gridStart)
					repeat {
						marks.insert(d)
						guard let next = c.date(byAdding: .day, value: 1, to: d) else { break }
						d = next
					} while d < min(e.end, gridEnd)
				}
				return (marks, Self.fetch(store, day, dayEnd), Self.fetch(store, tomorrowStart, tomorrowEnd))
			}.value
			guard !Task.isCancelled else { return }
			(marked, events, tomorrow) = result
		}
	}

	private static func status() -> Access {
		switch EKEventStore.authorizationStatus(for: .event) {
		case .fullAccess: .granted
		case .notDetermined: .unknown
		default: .denied
		}
	}

	private nonisolated static func fetch(_ store: EKEventStore, _ start: Date, _ end: Date) -> [Event] {
		store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
			.filter { $0.attendees?.first(where: \.isCurrentUser)?.participantStatus != .declined }
			.map { e in
				Event(
					id: "\(e.eventIdentifier ?? e.calendarItemIdentifier)|\(e.startDate.timeIntervalSince1970)",
					item: e.calendarItemIdentifier, title: e.title ?? "", start: e.startDate, end: e.endDate,
					isAllDay: e.isAllDay, location: place(e.location), isWork: isWork(e.calendar))
			}
			.sorted { $0.isAllDay != $1.isAllDay ? $0.isAllDay : $0.start < $1.start }
	}

	// A meeting link reads as its host.
	private nonisolated static func place(_ location: String?) -> String? {
		guard let line = location?.split(whereSeparator: \.isNewline).first?.trimmingCharacters(in: .whitespaces),
			!line.isEmpty
		else { return nil }
		if let host = URL(string: line)?.host() { return host.replacing(/^www\./, with: "") }
		return line
	}

	// Exchange and accounts on a non-consumer mail domain count as work.
	private nonisolated static func isWork(_ calendar: EKCalendar?) -> Bool {
		guard let source = calendar?.source else { return false }
		if source.sourceType == .exchange { return true }
		let parts = source.title.lowercased().split(separator: "@")
		guard parts.count == 2 else { return false }
		return ![
			"gmail.com", "googlemail.com", "icloud.com", "me.com", "mac.com", "outlook.com", "hotmail.com", "live.com",
			"yahoo.com",
		].contains(String(parts[1]))
	}
}
