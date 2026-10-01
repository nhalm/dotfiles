import SwiftUI

struct MediaPopup: View {
	@Environment(Media.self) private var media

	var body: some View {
		PopupCard(width: .regular) {
			if let now = media.now {
				HeroHeader(
					eyebrow: media.source?.name ?? "Now Playing", eyebrowImage: media.source?.icon, value: now.title,
					subtitle: now.byline, style: .text
				) {
					HeaderToggle(
						symbol: now.isPlaying ? "pause.fill" : "play.fill", isOn: now.isPlaying,
						label: now.isPlaying ? "Pause" : "Play"
					) { media.togglePlayPause() }
				}
				Artwork(image: media.artwork)
				ScrubBar(duration: now.duration, isPlaying: now.isPlaying, elapsed: now.elapsed(at:), seek: media.seek) {
					IconButton(symbol: "backward.fill", label: "Previous") { media.previous() }
					IconButton(symbol: "forward.fill", label: "Next") { media.next() }
				}
				if let source = media.source, source.url != nil {
					FooterLink("Open \(source.name)") { media.openSource() }
				}
			} else {
				EmptyState(symbol: "music.note", title: "Nothing playing")
			}
		}
	}
}
