import SwiftUI

struct Swatch: Hashable, Sendable {
	let role: String
	let hex: String
}

// Colours side by side in equal columns, each with its role and hex.
struct SwatchStrip: View {
	@Environment(\.theme) private var theme
	let swatches: [Swatch]

	init(_ swatches: [Swatch]) { self.swatches = swatches }

	var body: some View {
		HStack(alignment: .top, spacing: Space.s2) {
			ForEach(swatches, id: \.role) { s in
				VStack(alignment: .leading, spacing: Space.s1) {
					RoundedRectangle(cornerRadius: Radius.icon, style: .continuous)
						.fill(Color(hexString: s.hex) ?? theme.raised)
						.overlay {
							RoundedRectangle(cornerRadius: Radius.icon, style: .continuous)
								.strokeBorder(theme.hairline, lineWidth: 1)
						}
						.frame(height: 28)
						.padding(.bottom, 2)
					Text(s.role).foregroundStyle(theme.textSecondary)
					Text(s.hex).monospaced().foregroundStyle(theme.text)
				}
				.font(Theme.Font.caption)
				.lineLimit(1)
				.frame(maxWidth: .infinity, alignment: .leading)
				.accessibilityElement(children: .combine)
			}
		}
		.animation(Motion.palette, value: swatches)
	}
}
