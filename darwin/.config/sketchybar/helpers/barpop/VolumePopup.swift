import AppKit
import SwiftUI

struct VolumePopup: View {
	@Environment(Audio.self) private var audio

	var body: some View {
		PopupCard(width: .regular) {
			HeroHeader(
				eyebrow: audio.currentName, value: audio.muted ? "Muted" : "\(Int((audio.volume * 100).rounded()))",
				unit: audio.muted ? nil : "%", dimmed: audio.muted
			) {
				HeaderToggle(
					symbol: audio.muted ? "speaker.slash.fill" : "speaker.wave.3.fill", variableValue: audio.volume,
					isOn: !audio.muted, label: audio.muted ? "Unmute" : "Mute"
				) { audio.setMuted(!audio.muted) }
				.disabled(!audio.hasMute)
			}
			LevelSlider(
				label: "Volume", value: Binding(get: { audio.volume }, set: { audio.setVolume($0) }),
				minSymbol: "speaker.fill", maxSymbol: "speaker.wave.3.fill", isEnabled: audio.hasVolume,
				dimmed: audio.muted)
			Section("Output") {
				ForEach(audio.devices) { device in
					ListItem(
						title: device.name, subtitle: device.kind, symbol: device.symbol,
						isSelected: device.id == audio.current
					) { audio.select(device) }
				}
			}
			if !audio.inputs.isEmpty {
				Section("Input") {
					LevelSlider(
						label: "Input volume", value: Binding(get: { audio.inputVolume }, set: { audio.setInputVolume($0) }),
						minSymbol: "mic", maxSymbol: "mic.fill", isEnabled: audio.hasInputVolume)
					ForEach(audio.inputs) { device in
						ListItem(
							title: device.name, subtitle: device.kind, symbol: device.symbol,
							isSelected: device.id == audio.currentInput
						) { audio.select(device) }
					}
				}
			}
			FooterLink("Sound Settings…") {
				NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefpane"))
			}
		}
	}
}
