import SwiftUI

// Something to choose that belongs to a category, e.g. an event and its
// calendar: a colour strip leads, an optional chip trails.
struct StripItem: View {
	enum Tone { case accent, alt }

	@Environment(\.theme) private var theme
	let title: String
	var subtitle: String?
	var tone = Tone.accent
	var chip: String?
	let action: () -> Void
	@State private var hovering = false

	var body: some View {
		Button(action: action) {
			HStack(spacing: Space.s3) {
				VStack(alignment: .leading, spacing: 1) {
					Text(title).font(Theme.Font.body).foregroundStyle(theme.text).lineLimit(1)
					if let subtitle {
						Text(subtitle).font(Theme.Font.caption).foregroundStyle(theme.textSecondary).lineLimit(1)
					}
				}
				.padding(.leading, 3 + Space.s3)
				.background(alignment: .leading) {
					Capsule()
						.fill(tone == .accent ? theme.accent : theme.accentAlt)
						.frame(width: 3)
						.padding(.vertical, 2)
				}
				Spacer(minLength: 0)
				if let chip { Chip(chip) }
			}
			.frame(minHeight: 44)
			.contentShape(Rectangle())
		}
		.buttonStyle(RowStyle(hovering: hovering))
		.onHover { hovering = $0 }
		.animation(Motion.hover, value: hovering)
	}
}
