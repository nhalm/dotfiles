import AppKit
import SwiftUI

// A ValueRow whose value is copied on click. The copy glyph shows on hover;
// the value reads "Copied" for a moment after. The hover pill covers the
// hairlines beside the row.
struct CopyRow: View {
	@Environment(\.theme) private var theme
	let label: String
	let value: String
	var symbol: String?
	var variableValue: Double?
	@State private var hovering = false
	@State private var copied = false
	@State private var reset: Task<Void, Never>?

	init(_ label: String, value: String, symbol: String? = nil, variableValue: Double? = nil) {
		self.label = label
		self.value = value
		self.symbol = symbol
		self.variableValue = variableValue
	}

	var body: some View {
		Button(action: copy) {
			ValueRow(label) {
				if copied {
					HStack(spacing: Space.s1 + 2) {
						Image(systemName: "checkmark").font(Theme.Font.caption)
						Text("Copied")
					}
					.foregroundStyle(theme.accent)
				} else {
					HStack(spacing: Space.s2) {
						if let symbol {
							Image(systemName: symbol, variableValue: variableValue).foregroundStyle(theme.accent)
						}
						Text(value).monospacedDigit()
						if hovering {
							Image(systemName: "doc.on.doc").font(Theme.Font.caption).foregroundStyle(theme.textSecondary)
						}
					}
				}
			}
			.contentTransition(.interpolate)
			.contentShape(Rectangle())
		}
		.buttonStyle(CopyRowStyle(hovering: hovering))
		.onHover { hovering = $0 }
		.animation(Motion.hover, value: hovering)
		.animation(Motion.select, value: copied)
		.zIndex(hovering ? 1 : 0)
		.containerValue(\.divided, true)
		.accessibilityHint("Copies \(value)")
	}

	private func copy() {
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(value, forType: .string)
		copied = true
		reset?.cancel()
		reset = Task {
			try? await Task.sleep(for: .seconds(1.2))
			if !Task.isCancelled { copied = false }
		}
	}
}

private struct CopyRowStyle: ButtonStyle {
	@Environment(\.theme) private var theme
	let hovering: Bool

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.padding(.horizontal, Space.s2)
			.background {
				RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
					.fill(configuration.isPressed ? theme.pressed : (hovering ? theme.raised : .clear))
					.padding(.vertical, -1)
			}
			.padding(.horizontal, -Space.s2)
	}
}
