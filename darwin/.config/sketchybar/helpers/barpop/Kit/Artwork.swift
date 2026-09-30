import AppKit
import SwiftUI

// Cover art on a tile the card's width, at the image's own shape between
// 16:9 and square; a glyph on a raised tile when there is none. A hairline
// keeps dark covers off the card.
struct Artwork: View {
	@Environment(\.theme) private var theme
	let image: NSImage?
	var placeholder = "music.note"

	var body: some View {
		let aspect = image.map { min(max($0.size.width / max($0.size.height, 1), 1), 16 / 9) } ?? 16 / 9
		Color.clear
			.aspectRatio(aspect, contentMode: .fit)
			.frame(maxWidth: .infinity)
			.overlay {
				if let image {
					Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
				} else {
					Image(systemName: placeholder).font(.system(size: 28)).foregroundStyle(theme.textTertiary)
				}
			}
			.background(theme.raised)
			.clipShape(.rect(cornerRadius: Radius.tile, style: .continuous))
			.overlay {
				if image != nil {
					RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(theme.hairline, lineWidth: 1)
				}
			}
	}
}
