import SwiftUI

// How full something is, 0…1. Live sweeps a sheen along the fill while the
// level is rising, e.g. a charging battery.
struct LevelMeter: View {
	enum Tone { case accent, critical }

	@Environment(\.theme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
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

// A live level, 0…1, e.g. a mic's input, as segments lit left to right; the
// highest recent segment stays lit briefly. The caller smooths the value.
// `under`: the min/max glyphs of a LevelSlider above it, whose widths it
// reserves so the two tracks line up; `symbol` sits in the leading slot.
struct SegmentMeter: View {
	@Environment(\.theme) private var theme
	let value: Double
	var segments = 16
	var symbol: String?
	var under: (min: String, max: String)?
	@State private var peak = 0
	@State private var peakAt = Date.distantPast

	var body: some View {
		let lit = Int((min(max(value, 0), 1) * Double(segments)).rounded())
		HStack(spacing: Space.s3) {
			if symbol != nil || under != nil {
				ZStack {
					if let under { Image(systemName: under.min).hidden() }
					if let symbol { Image(systemName: symbol) }
				}
			}
			HStack(spacing: 3) {
				ForEach(0..<segments, id: \.self) { i in
					Capsule()
						.fill(i < lit || (i == peak - 1 && peak > lit) ? theme.accent : theme.raised)
						.frame(maxWidth: .infinity)
						.frame(height: 4)
				}
			}
			if let under { Image(systemName: under.max).hidden() }
		}
		.font(.system(size: 13))
		.foregroundStyle(theme.textSecondary)
		.onChange(of: value) {
			if lit >= peak || Date().timeIntervalSince(peakAt) > 0.8 {
				peak = lit
				peakAt = Date()
			}
		}
		.accessibilityElement()
		.accessibilityLabel("Level")
		.accessibilityValue("\(Int((value * 100).rounded()))%")
	}
}
