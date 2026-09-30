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
			FooterLink("Sound Settings…") {
				NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Sound.prefpane"))
			}
		}
	}
}
