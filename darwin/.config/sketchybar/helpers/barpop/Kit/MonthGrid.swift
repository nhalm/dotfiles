import SwiftUI

// A month in weeks from the locale's first weekday, edged by the months
// either side. Today is accent, the selected day accentSoft, marked days
// (midnights) carry a dot.
struct MonthGrid: View {
	@Environment(\.theme) private var theme
	let month: Date
	let today: Date
	var selected: Date?
	let marked: Set<Date>
	let onSelect: (Date) -> Void

	var body: some View {
		let c = Calendar.current
		let days = Self.days(in: month)
		let symbols = c.veryShortStandaloneWeekdaySymbols
		Grid(horizontalSpacing: 0, verticalSpacing: 0) {
			GridRow {
				ForEach(0..<7, id: \.self) { i in
					Text(symbols[(i + c.firstWeekday - 1) % 7])
						.font(Theme.Font.caption)
						.foregroundStyle(theme.textSecondary)
						.frame(maxWidth: .infinity, minHeight: 24)
				}
			}
			ForEach(0..<days.count / 7, id: \.self) { week in
				GridRow {
					ForEach(days[week * 7..<week * 7 + 7], id: \.self) { day in
						DayCell(
							day: day, inMonth: c.isDate(day, equalTo: month, toGranularity: .month),
							isToday: c.isDate(day, inSameDayAs: today),
							isSelected: selected.map { c.isDate(day, inSameDayAs: $0) } ?? false,
							isMarked: marked.contains(day)
						) { onSelect(day) }
					}
				}
			}
		}
	}

	// Midnights of every day shown for month, in whole weeks.
	static func days(in month: Date) -> [Date] {
		let c = Calendar.current
		guard let first = c.dateInterval(of: .month, for: month)?.start,
			let count = c.range(of: .day, in: .month, for: first)?.count
		else { return [] }
		let lead = (c.component(.weekday, from: first) - c.firstWeekday + 7) % 7
		let weeks = (lead + count + 6) / 7
		return (0..<weeks * 7).compactMap { c.date(byAdding: .day, value: $0 - lead, to: first) }
	}
}

private struct DayCell: View {
	@Environment(\.theme) private var theme
	let day: Date
	let inMonth: Bool
	let isToday: Bool
	let isSelected: Bool
	let isMarked: Bool
	let action: () -> Void
	@State private var hovering = false

	var body: some View {
		Button(action: action) {
			Text("\(Calendar.current.component(.day, from: day))")
				.font(.system(size: 13, design: .rounded).monospacedDigit())
				.foregroundStyle(ink)
				.frame(width: 30, height: 30)
				.background(Circle().fill(fill))
				.frame(maxWidth: .infinity, minHeight: 36)
				.overlay(alignment: .bottom) {
					if isMarked && !isToday {
						Circle().fill(theme.accentAlt).frame(width: 4, height: 4).padding(.bottom, 1)
					}
				}
				.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.onHover { hovering = $0 }
		.animation(Motion.hover, value: hovering)
		.animation(Motion.select, value: isSelected)
		.accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).month().day()))
	}

	private var ink: Color {
		if isToday { return theme.onAccent }
		if isSelected { return theme.onAccentSoft }
		if !inMonth { return theme.textTertiary }
		return Calendar.current.isDateInWeekend(day) ? theme.textSecondary : theme.text
	}

	private var fill: Color {
		if isToday { return theme.accent }
		if isSelected { return theme.accentSoft }
		return hovering ? theme.raised : .clear
	}
}
