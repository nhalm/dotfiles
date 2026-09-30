import SwiftUI

struct WallpaperPopup: View {
	private static let columns = 3

	@Environment(Wallpapers.self) private var wallpapers
	@Environment(Palette.self) private var palette

	var body: some View {
		@Bindable var wallpapers = wallpapers
		let matches = wallpapers.matches
		PopupCard(width: .wide) {
			HeroHeader(
				eyebrow: "Wallpaper", eyebrowChip: chip, value: wallpapers.currentWallpaper?.name ?? "None",
				subtitle: wallpapers.currentDetail, style: .text, dimmed: wallpapers.current == nil)
			SearchField(
				text: $wallpapers.query, prompt: "Filter \(wallpapers.all.count) wallpapers",
				onMove: move, onSubmit: wallpapers.submit)
			Section(
				"Library",
				trailing: matches.count == wallpapers.all.count
					? "\(matches.count)" : "\(matches.count) of \(wallpapers.all.count)"
			) {
				if matches.isEmpty {
					EmptyState(symbol: "photo.on.rectangle", title: "No matches")
				} else {
					ThumbGrid(columns: Self.columns) {
						ForEach(matches) { w in
							Thumbnail(
								image: wallpapers.thumbnails[w.key], label: w.name, isCurrent: w.path == wallpapers.current,
								isHighlighted: w.path == wallpapers.highlighted, onHover: { wallpapers.hover(w, $0) }
							) { wallpapers.apply(w) }
						}
					}
				}
			}
			if let preview = wallpapers.preview {
				Section("Palette from \(preview.name)", trailing: "Click to apply") {
					SwatchStrip(preview.swatches)
				}
			}
			FooterLink("Open Folder", detail: Wallpapers.displayFolder) { wallpapers.openFolder() }
		}
		.onChange(of: palette.roles) { wallpapers.paletteChanged() }
	}

	private var chip: Chip? {
		switch wallpapers.applying {
		case .idle: nil
		case .running: Chip("Applying…", pulsing: true)
		case .done: Chip("Applied")
		}
	}

	private func move(_ m: SearchField.Move) {
		switch m {
		case .left: wallpapers.move(by: -1)
		case .right: wallpapers.move(by: 1)
		case .up: wallpapers.move(by: -Self.columns)
		case .down: wallpapers.move(by: Self.columns)
		}
	}
}
