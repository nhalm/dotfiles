import SwiftUI

struct VolumeView: View {
	@Environment(Palette.self) private var palette
	@Environment(Audio.self) private var audio
	@State private var appeared = false

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			header
			LevelSlider(value: Binding(get: { audio.muted ? 0 : audio.volume }, set: { audio.setVolume($0) }))
				.disabled(!audio.hasVolume)
				.opacity(audio.hasVolume ? 1 : 0.4)
			Rectangle().fill(palette.outline).frame(height: 1)
			devices
		}
		.padding(18)
		.frame(width: 300)
		.background(card)
		.font(.system(size: 13, design: .rounded))
		.foregroundStyle(palette.onSurface)
		.scaleEffect(appeared ? 1 : 0.94, anchor: .top)
		.opacity(appeared ? 1 : 0)
		.offset(y: appeared ? 0 : -8)
		.onAppear {
			withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { appeared = true }
		}
	}

	private var header: some View {
		HStack(spacing: 14) {
			Button {
				withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { audio.setMuted(!audio.muted) }
			} label: {
				ZStack {
					Circle().fill(palette.primary.opacity(audio.muted ? 0.08 : 0.2))
					Image(systemName: audio.muted ? "speaker.slash.fill" : "speaker.wave.3.fill",
						variableValue: audio.volume)
						.font(.system(size: 20, weight: .semibold))
						.foregroundStyle(audio.muted ? palette.onSurfaceVariant : palette.primary)
						.symbolEffect(.bounce, value: audio.muted)
						.contentTransition(.symbolEffect(.replace))
				}
				.frame(width: 48, height: 48)
			}
			.buttonStyle(.plain)
			.disabled(!audio.hasMute)
			.opacity(audio.hasMute ? 1 : 0.4)
			.help(audio.muted ? "Unmute" : "Mute")
			.accessibilityLabel(audio.muted ? "Unmute" : "Mute")

			VStack(alignment: .leading, spacing: 2) {
				Text(audio.currentName.uppercased())
					.font(.system(size: 10, weight: .semibold, design: .rounded))
					.tracking(0.8)
					.foregroundStyle(palette.onSurfaceVariant)
					.lineLimit(1)
				Text(audio.muted ? "Muted" : "\(Int((audio.volume * 100).rounded()))%")
					.font(.system(size: 30, weight: .semibold, design: .rounded))
					.monospacedDigit()
					.contentTransition(.numericText(value: audio.volume))
					.animation(.snappy(duration: 0.2), value: audio.volume)
			}
			Spacer(minLength: 0)
		}
	}

	private var devices: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("OUTPUT")
				.font(.system(size: 10, weight: .semibold, design: .rounded))
				.tracking(0.8)
				.foregroundStyle(palette.onSurfaceVariant)
				.padding(.bottom, 2)
			ForEach(audio.devices) { device in
				DeviceRow(device: device, selected: device.id == audio.current) { audio.select(device) }
			}
		}
	}

	private var card: some View {
		RoundedRectangle(cornerRadius: 18, style: .continuous)
			.fill(palette.container)
			.overlay(
				RoundedRectangle(cornerRadius: 18, style: .continuous).fill(
					LinearGradient(
						colors: [palette.primaryContainer.opacity(0.55), .clear],
						startPoint: .topLeading, endPoint: .center))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(palette.outline, lineWidth: 1)
			)
			.shadow(color: .black.opacity(0.4), radius: 16, y: 8)
	}
}

// While dragging, the knob follows the pointer rather than the device, which
// quantizes each write and echoes it back; writes are throttled to ~30Hz.
struct LevelSlider: View {
	@Environment(Palette.self) private var palette
	@Binding var value: Double
	@State private var hovering = false
	@State private var drag: Double?
	@State private var written = Date.distantPast

	var body: some View {
		GeometryReader { geo in
			let knob: CGFloat = drag != nil ? 22 : 18
			let x = CGFloat(drag ?? value) * (geo.size.width - knob)
			ZStack(alignment: .leading) {
				Capsule().fill(palette.containerHigh)
				Capsule()
					.fill(LinearGradient(colors: [palette.primary, palette.tertiary], startPoint: .leading, endPoint: .trailing))
					.frame(width: x + knob)
				Circle()
					.fill(palette.onSurface)
					.frame(width: knob, height: knob)
					.shadow(color: .black.opacity(0.35), radius: 3, y: 1)
					.offset(x: x)
			}
			.frame(height: hovering || drag != nil ? 14 : 10)
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
			.animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering || drag != nil)
		}
		.frame(height: 24)
		.accessibilityElement()
		.accessibilityLabel("Volume")
		.accessibilityValue("\(Int((value * 100).rounded()))%")
		.accessibilityAdjustableAction { direction in
			switch direction {
			case .increment: value = min(value + 0.05, 1)
			case .decrement: value = max(value - 0.05, 0)
			@unknown default: break
			}
		}
	}
}

struct DeviceRow: View {
	@Environment(Palette.self) private var palette
	let device: OutputDevice
	let selected: Bool
	let action: () -> Void
	@State private var hovering = false

	var body: some View {
		Button(action: action) {
			HStack(spacing: 10) {
				Image(systemName: device.symbol)
					.frame(width: 18)
					.foregroundStyle(selected ? palette.primary : palette.onSurfaceVariant)
				Text(device.name).lineLimit(1)
				Spacer(minLength: 0)
				if selected {
					Image(systemName: "checkmark")
						.font(.system(size: 11, weight: .bold))
						.foregroundStyle(palette.primary)
						.transition(.scale.combined(with: .opacity))
				}
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
			.background(
				RoundedRectangle(cornerRadius: 9, style: .continuous)
					.fill(
						selected
							? palette.primaryContainer.opacity(0.6)
							: (hovering ? palette.containerHigh : Color.clear))
			)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.onHover { hovering = $0 }
		.animation(.easeOut(duration: 0.15), value: hovering)
		.animation(.spring(response: 0.3, dampingFraction: 0.75), value: selected)
	}
}
