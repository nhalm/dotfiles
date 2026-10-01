import SwiftUI

// While dragging, the knob follows the pointer rather than the model, which
// may quantize each write and echo it back; writes are throttled to ~30Hz.
struct LevelSlider: View {
	@Environment(\.theme) private var theme
	let label: String
	@Binding var value: Double
	var minSymbol: String?
	var maxSymbol: String?
	var isEnabled = true
	// Shown, still adjustable, but not in effect (muted).
	var dimmed = false
	// A live level 0…1 in the track, e.g. a mic's input; the caller smooths it.
	var live: Double?
	@State private var hovering = false
	@State private var drag: Double?
	@State private var written = Date.distantPast

	var body: some View {
		HStack(spacing: Space.s3) {
			if let minSymbol { Image(systemName: minSymbol) }
			track
			if let maxSymbol { Image(systemName: maxSymbol) }
		}
		.font(.system(size: 13))
		.foregroundStyle(theme.textSecondary)
		.opacity(isEnabled ? 1 : 0.4)
		.disabled(!isEnabled)
		.accessibilityElement()
		.accessibilityLabel(label)
		.accessibilityValue("\(Int((value * 100).rounded()))%")
		.accessibilityAdjustableAction { direction in
			guard isEnabled else { return }
			switch direction {
			case .increment: value = min(value + 0.05, 1)
			case .decrement: value = max(value - 0.05, 0)
			@unknown default: break
			}
		}
	}

	private var track: some View {
		GeometryReader { geo in
			let engaged = isEnabled && (hovering || drag != nil)
			let knob: CGFloat = engaged ? 22 : 20
			let x = CGFloat(drag ?? value) * (geo.size.width - knob)
			ZStack(alignment: .leading) {
				Capsule().fill(theme.raised)
				Capsule()
					.fill(dimmed ? theme.textTertiary : theme.accent)
					.frame(width: x + knob / 2)
				// Over the gain fill: a full-gain input would hide it underneath.
				if let live {
					Rectangle()
						.fill(theme.accentAlt.opacity(0.7))
						.frame(width: CGFloat(min(max(live, 0), 1)) * geo.size.width)
				}
			}
			.frame(height: engaged ? 8 : 6)
			.clipShape(Capsule())
			.overlay(alignment: .leading) {
				Circle()
					.fill(dimmed ? theme.textSecondary : theme.text)
					.frame(width: knob, height: knob)
					.shadow(color: .black.opacity(0.45), radius: 1, y: 1)
					.offset(x: x)
			}
			.frame(maxHeight: .infinity)
			.contentShape(Rectangle())
			.gesture(
				DragGesture(minimumDistance: 0)
					.onChanged { g in
						let v = Double(min(max((g.location.x - knob / 2) / (geo.size.width - knob), 0), 1))
						drag = v
						if Date().timeIntervalSince(written) >= 1.0 / 30 {
							value = v
							written = Date()
						}
					}
					.onEnded { _ in
						if let drag { value = drag }
						drag = nil
					}
			)
			.onHover { hovering = $0 }
			.animation(Motion.engage, value: engaged)
		}
		.frame(height: 24)
	}
}
