import SwiftUI

// A glyph-only secondary action: previous/next, a month chevron.
struct IconButton: View {
	@Environment(\.theme) private var theme
	@Environment(\.isEnabled) private var isEnabled
	let symbol: String
	let label: String
	let action: () -> Void
	@State private var hovering = false

	var body: some View {
		Button(action: action) {
			Image(systemName: symbol)
				.font(Theme.Font.label)
				.foregroundStyle(hovering ? theme.text : theme.textSecondary)
				.frame(width: 24, height: 24)
				.background(Circle().fill(hovering ? theme.pressed : .clear))
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.opacity(isEnabled ? 1 : 0.4)
		.onHover { hovering = $0 }
		.animation(Motion.hover, value: hovering)
		.help(label)
		.accessibilityLabel(label)
	}
}
