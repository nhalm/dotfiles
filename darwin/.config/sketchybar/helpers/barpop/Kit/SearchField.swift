import AppKit
import SwiftUI

// A filter over a list or grid. It takes the keyboard as it appears, making
// the non-activating panel key without activating barpop, so typing lands
// here while the app you're in stays frontmost. Arrows move a highlight in
// what it filters; return picks it.
struct SearchField: View {
	enum Move { case up, down, left, right }

	@Environment(\.theme) private var theme
	@Binding var text: String
	let prompt: String
	var onMove: (Move) -> Void = { _ in }
	var onSubmit: () -> Void = {}
	@FocusState private var focused: Bool

	var body: some View {
		HStack(spacing: Space.s2) {
			Image(systemName: "magnifyingglass").foregroundStyle(theme.textSecondary)
			// AppKit draws a prompt in its own placeholder grey.
			TextField("", text: $text)
				.textFieldStyle(.plain)
				.background(alignment: .leading) {
					if text.isEmpty { Text(prompt).foregroundStyle(theme.textSecondary).allowsHitTesting(false) }
				}
				.accessibilityLabel(prompt)
				.foregroundStyle(theme.text)
				.tint(theme.accent)
				.focused($focused)
				.onSubmit(onSubmit)
				.onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
					switch press.key {
					case .upArrow: onMove(.up)
					case .downArrow: onMove(.down)
					case .leftArrow: onMove(.left)
					default: onMove(.right)
					}
					return .handled
				}
			if !text.isEmpty {
				Button { text = "" } label: {
					Image(systemName: "xmark.circle.fill").foregroundStyle(theme.textSecondary)
				}
				.buttonStyle(.plain)
				.accessibilityLabel("Clear")
			}
		}
		.font(Theme.Font.body)
		.padding(.horizontal, Space.s3)
		.frame(height: 32)
		.background(theme.raised, in: .rect(cornerRadius: Radius.row, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
				.strokeBorder(theme.accent.opacity(focused ? 0.7 : 0), lineWidth: 1)
		}
		.background(KeyWindow { focused = true })
		.animation(Motion.hover, value: focused)
	}
}

// Makes its window key once it is in one, then hands over focus; deferred
// a turn, since the panel is ordered front only after its views are built.
private struct KeyWindow: NSViewRepresentable {
	let onKey: () -> Void

	func makeNSView(context: Context) -> NSView { KeyView(onKey: onKey) }
	func updateNSView(_ view: NSView, context: Context) {}

	final class KeyView: NSView {
		let onKey: () -> Void

		init(onKey: @escaping () -> Void) {
			self.onKey = onKey
			super.init(frame: .zero)
		}

		required init?(coder: NSCoder) { nil }

		override func viewDidMoveToWindow() {
			guard window != nil else { return }
			DispatchQueue.main.async { [weak self] in
				MainActor.assumeIsolated {
					guard let self, let window = self.window else { return }
					window.makeKey()
					self.onKey()
				}
			}
		}
	}
}
