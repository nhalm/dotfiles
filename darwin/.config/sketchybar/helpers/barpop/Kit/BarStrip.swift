import SwiftUI

struct BarGroup: Identifiable {
	var label: String?
	let values: [Double]

	var id: String { label ?? "" }
}

// Levels side by side as small vertical bars, 0…1, e.g. each CPU core. Every
// bar has the same width; groups sit apart, each captioned below.
struct BarStrip: View {
	@Environment(\.theme) private var theme
	let groups: [BarGroup]

	init(_ groups: [BarGroup]) { self.groups = groups }

	private static let gap: CGFloat = 3
	private static let height: CGFloat = 36

	var body: some View {
		let n = groups.reduce(0) { $0 + $1.values.count }
		let captioned = groups.contains { $0.label != nil }
		GeometryReader { geo in
			let gaps = CGFloat(n - groups.count) * Self.gap + CGFloat(groups.count - 1) * Space.s3
			let w = max((geo.size.width - gaps) / CGFloat(max(n, 1)), 2)
			HStack(alignment: .top, spacing: Space.s3) {
				ForEach(groups) { g in
					VStack(alignment: .leading, spacing: Space.s1 + 2) {
						HStack(spacing: Self.gap) {
							ForEach(Array(g.values.enumerated()), id: \.offset) { _, v in
								bar(v).frame(width: w)
							}
						}
						if let label = g.label {
							Text(label).font(Theme.Font.caption).foregroundStyle(theme.textSecondary).lineLimit(1)
						}
					}
					.accessibilityElement()
					.accessibilityLabel(g.label ?? "")
					.accessibilityValue(g.values.map { "\(Int(($0 * 100).rounded()))%" }.joined(separator: ", "))
				}
			}
		}
		.frame(height: Self.height + (captioned ? Space.s1 + 2 + 14 : 0))
	}

	private func bar(_ value: Double) -> some View {
		let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
		return shape.fill(theme.raised)
			.overlay(alignment: .bottom) {
				shape.fill(theme.accent).frame(height: max(CGFloat(min(max(value, 0), 1)) * Self.height, 3))
			}
			.clipShape(shape)
			.frame(height: Self.height)
			.animation(Motion.numeric, value: value)
	}
}
