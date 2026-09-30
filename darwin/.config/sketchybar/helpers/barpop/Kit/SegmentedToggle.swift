import SwiftUI

// A few ways to show the same thing, e.g. sort by CPU or by memory; small
// enough for a SectionLabel accessory. The chosen one sits on accentSoft.
struct SegmentedToggle<Value: Hashable>: View {
	@Environment(\.theme) private var theme
	@Namespace private var namespace
	let options: [(label: String, value: Value)]
	@Binding var selection: Value

	init(_ options: [(label: String, value: Value)], selection: Binding<Value>) {
		self.options = options
		_selection = selection
	}

	var body: some View {
		HStack(spacing: 0) {
			ForEach(Array(options.enumerated()), id: \.offset) { _, option in
				let on = option.value == selection
				Button {
					withAnimation(Motion.select) { selection = option.value }
				} label: {
					Text(option.label)
						.font(Theme.Font.caption)
						.foregroundStyle(on ? theme.onAccentSoft : theme.textSecondary)
						.padding(.horizontal, Space.s2 + 2)
						.frame(height: 20)
						.background {
							if on { Capsule().fill(theme.accentSoft).matchedGeometryEffect(id: "on", in: namespace) }
						}
						.contentShape(Capsule())
				}
				.buttonStyle(.plain)
				.accessibilityAddTraits(on ? .isSelected : [])
			}
		}
		.padding(2)
		.background(Capsule().fill(theme.raised))
	}
}
