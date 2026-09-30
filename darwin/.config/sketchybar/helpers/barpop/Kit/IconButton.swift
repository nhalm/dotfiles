import SwiftUI

// A small glyph-only action, e.g. paging a month.
struct IconButton: View {
	@Environment(\.theme) private var theme
	let symbol: String
	let label: String
	let action: () -> Void
	@State private var hovering = false

	var body: some View {
		Button(action: action) {
			Image(systemName: symbol)
				.font(.system(size: 12))
				.foregroundStyle(hovering ? theme.text : theme.textSecondary)
				.frame(width: 24, height: 24)
				.background(Circle().fill(hovering ? theme.pressed : .clear))
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.onHover { hovering = $0 }
		.animation(Motion.hover, value: hovering)
		.help(label)
		.accessibilityLabel(label)
	}
}
