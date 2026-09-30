import SwiftUI

// Position in a track: a LevelSlider over the elapsed time, elapsed and
// remaining below it with optional controls centred between them. The time
// runs on while playing; a drag seeks once it settles, not on every step.
// No duration (a live stream) leaves the track idle.
struct ScrubBar<Controls: View>: View {
	@Environment(\.theme) private var theme
	let duration: TimeInterval?
	let isPlaying: Bool
	let elapsed: (Date) -> TimeInterval
	let seek: (TimeInterval) -> Void
	@ViewBuilder var controls: Controls
	@State private var pending: TimeInterval?
	@State private var settle: Task<Void, Never>?

	var body: some View {
		TimelineView(.animation(minimumInterval: 0.5, paused: !isPlaying || pending != nil)) { context in
			let length = duration ?? 0
			let t = pending ?? elapsed(context.date)
			VStack(spacing: Space.s1) {
				LevelSlider(
					label: "Position",
					value: Binding(get: { length > 0 ? t / length : 0 }, set: { scrub(to: $0 * length) }),
					isEnabled: length > 0)
				ZStack {
					HStack {
						Text(clock(t))
						Spacer(minLength: Space.s2)
						Text(length > 0 ? "-" + clock(length - t) : "Live")
					}
					.font(Theme.Font.caption)
					.monospacedDigit()
					.foregroundStyle(theme.textSecondary)
					HStack(spacing: Space.s3) { controls }
				}
			}
		}
	}

	private func scrub(to t: TimeInterval) {
		pending = t
		settle?.cancel()
		settle = Task {
			try? await Task.sleep(for: .milliseconds(250))
			guard !Task.isCancelled else { return }
			seek(t)
			// Hold the new position until the player reports it.
			try? await Task.sleep(for: .seconds(1))
			guard !Task.isCancelled else { return }
			pending = nil
		}
	}

	private func clock(_ seconds: TimeInterval) -> String {
		let s = Int(max(seconds, 0).rounded(.down))
		return s >= 3600
			? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
	}
}
