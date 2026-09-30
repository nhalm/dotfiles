import AppKit
import SwiftUI

struct BatteryPopup: View {
	@Environment(Battery.self) private var battery
	@Environment(Presentation.self) private var presentation

	var body: some View {
		PopupCard(width: .regular) {
			if battery.isPresent {
				HeroHeader(
					eyebrow: "Battery", eyebrowChip: battery.isLow ? Chip("Low", tone: .critical) : nil,
					value: "\(battery.percent)", unit: "%", subtitle: status,
					subtitleSymbol: battery.isCharging ? "bolt.fill" : nil
				) {
					HeaderToggle(
						symbol: battery.lowPower ? "leaf.fill" : "leaf", isOn: battery.lowPower, attention: battery.isLow,
						label: battery.lowPower ? "Turn off Low Power Mode" : "Turn on Low Power Mode"
					) { battery.setLowPower(!battery.lowPower) }
				}
				LevelMeter(
					value: Double(battery.percent) / 100, tone: battery.isLow ? .critical : .accent,
					isLive: battery.isCharging)
				Section("Health") {
					ValueRow("Power source") { Text(battery.onAC ? "Power Adapter" : "Battery") }
					if let charger = battery.charger, !charger.isEmpty { ValueRow("Charger") { Text(charger) } }
					if let condition = battery.condition { ValueRow("Condition") { Text(condition) } }
					if let max = battery.maxCapacity { ValueRow("Maximum capacity") { Text("\(max)%") } }
					if let cycles = battery.cycles { ValueRow("Cycle count") { Text("\(cycles)") } }
				}
				if !battery.onAC && !battery.energy.isEmpty {
					Section("Using significant energy") {
						ForEach(battery.energy) { app in
							ListItem(title: app.name, symbol: "app", icon: app.icon) {
								battery.activate(app)
								presentation.close()
							}
						}
					}
				}
			} else {
				EmptyState(symbol: "powerplug", title: "No battery", message: "This Mac runs on power from the wall.")
			}
			FooterLink("Battery Settings…") {
				if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") {
					NSWorkspace.shared.open(url)
				}
			}
		}
	}

	private var status: String {
		if battery.isCharging {
			return battery.minutesToFull.map { "Charging · \(clock($0)) to full" } ?? "Charging"
		}
		if battery.onAC { return battery.isCharged || battery.percent >= 100 ? "Fully charged" : "Not charging" }
		return battery.minutesToEmpty.map { "\(clock($0)) remaining" } ?? "Calculating time remaining"
	}

	private func clock(_ minutes: Int) -> String { String(format: "%d:%02d", minutes / 60, minutes % 60) }
}
