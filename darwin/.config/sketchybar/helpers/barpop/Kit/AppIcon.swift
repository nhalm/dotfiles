import AppKit
import SwiftUI

// An app's own icon at IconTile's size; the icon brings its own shape.
struct AppIcon: View {
	let image: NSImage

	var body: some View {
		Image(nsImage: image)
			.resizable()
			.interpolation(.high)
			.frame(width: 28, height: 28)
	}
}
