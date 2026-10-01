import SwiftUI

// How full something is, 0…1. Live sweeps a sheen along the fill while the
// level is rising, e.g. a charging battery.
struct LevelMeter: View {
	enum Tone { case accent, critical }

	@Environment(\.theme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.isEnabled) private var isEnabled
	let value: Double
	var tone = Tone.accent
	var isLive = false

	var body: some View {
		GeometryReader { geo in
			let fill = max(CGFloat(min(max(value, 0), 1)) * geo.size.width, geo.size.height)
			ZStack(alignment: .leading) {
				Capsule().fill(theme.raised)
				Capsule()
					.fill(tone == .critical ? theme.critical : theme.accent)
					.frame(width: fill)
					.overlay(alignment: .leading) {
						if isLive && !reduceMotion { Sheen(width: fill).clipShape(Capsule()) }
					}
			}
		}
		.frame(height: 8)
		.opacity(isEnabled ? 1 : 0.4)
		.animation(Motion.numeric, value: value)
		.accessibilityElement()
		.accessibilityValue("\(Int((value * 100).rounded()))%")
	}
}

private struct Sheen: View {
	let width: CGFloat

	var body: some View {
		TimelineView(.animation) { context in
			let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
			let band = max(width * 0.4, 24)
			LinearGradient(colors: [.clear, .white.opacity(0.32), .clear], startPoint: .leading, endPoint: .trailing)
				.frame(width: band)
				.offset(x: -band + CGFloat(phase) * (width + band))
		}
		.frame(width: width, alignment: .leading)
		.allowsHitTesting(false)
	}
}
