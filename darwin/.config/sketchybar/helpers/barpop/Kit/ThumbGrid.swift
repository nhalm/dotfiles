import AppKit
import SwiftUI

// Pictures to choose from in equal columns, 8pt apart.
struct ThumbGrid<Content: View>: View {
	let columns: Int
	@ViewBuilder let content: Content

	var body: some View {
		Group(subviews: content) { thumbs in
			VStack(spacing: Space.s2) {
				ForEach(Array(stride(from: 0, to: thumbs.count, by: columns)), id: \.self) { start in
					HStack(spacing: Space.s2) {
						ForEach(thumbs[start..<min(start + columns, thumbs.count)]) { $0 }
						ForEach(0..<max(start + columns - thumbs.count, 0), id: \.self) { _ in
							Color.clear.frame(maxWidth: .infinity)
						}
					}
				}
			}
		}
	}
}

// A picture to choose, at 16:10. Hover (or a highlight from the keyboard)
// lifts it with a ring; the current one has an accent ring and a check.
struct Thumbnail: View {
	@Environment(\.theme) private var theme
	let image: NSImage?
	let label: String
	var isCurrent = false
	var isHighlighted = false
	var onHover: (Bool) -> Void = { _ in }
	let action: () -> Void
	@State private var hovering = false

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.row, style: .continuous) }

	var body: some View {
		let lifted = hovering || isHighlighted
		Button(action: action) {
			Color.clear
				.aspectRatio(16 / 10, contentMode: .fit)
				.frame(maxWidth: .infinity)
				.overlay {
					if let image {
						Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
							.transition(.opacity)
					}
				}
				.background(theme.raised)
				.clipShape(shape)
				.overlay { shape.strokeBorder(theme.hairline, lineWidth: 1) }
				.overlay(alignment: .bottomTrailing) {
					if isCurrent {
						Image(systemName: "checkmark")
							.font(.system(size: 9, weight: .semibold))
							.foregroundStyle(theme.onAccent)
							.frame(width: 18, height: 18)
							.background(Circle().fill(theme.accent))
							.padding(Space.s1 + 2)
							.transition(.scale(scale: 0.6).combined(with: .opacity))
					}
				}
				.overlay {
					if isCurrent || lifted {
						RoundedRectangle(cornerRadius: Radius.row + 3.5, style: .continuous)
							.strokeBorder(isCurrent ? theme.accent : theme.text, lineWidth: 1.5)
							.padding(-3.5)
					}
				}
				.contentShape(shape)
		}
		.buttonStyle(.plain)
		.scaleEffect(lifted ? 1.03 : 1)
		.zIndex(lifted ? 1 : 0)
		.onHover {
			hovering = $0
			onHover($0)
		}
		.animation(Motion.hover, value: lifted)
		.animation(Motion.select, value: isCurrent)
		.animation(Motion.hover, value: image != nil)
		.help(label)
		.accessibilityLabel(label)
		.accessibilityAddTraits(isCurrent ? .isSelected : [])
	}
}
