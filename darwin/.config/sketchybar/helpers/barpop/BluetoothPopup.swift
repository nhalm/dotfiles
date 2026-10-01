import AppKit
import SwiftUI

struct BluetoothPopup: View {
	@Environment(Bluetooth.self) private var bluetooth

	var body: some View {
		let connected = bluetooth.connected
		let paired = bluetooth.paired
		PopupCard(width: .regular) {
			HeroHeader(
				eyebrow: "Bluetooth", value: bluetooth.isOn ? "On" : "Off", subtitle: summary,
				style: .text, dimmed: !bluetooth.isOn
			) {
				HeaderToggle(
					symbol: "bluetooth", isOn: bluetooth.isOn, label: bluetooth.isOn ? "Turn Bluetooth off" : "Turn Bluetooth on"
				) { bluetooth.setPower(!bluetooth.isOn) }
			}
			if !bluetooth.isOn {
				EmptyState(
					symbol: "antenna.radiowaves.left.and.right.slash", title: "Bluetooth is off",
					message: "Turn it on to use your devices.")
			} else if connected.isEmpty && paired.isEmpty {
				EmptyState(symbol: "wave.3.right", title: "No devices", message: "Pair one in Bluetooth Settings.")
			} else {
				if !connected.isEmpty {
					Section("Connected") {
						ForEach(connected) { device in
							ListItem(
								title: device.name, subtitle: device.battery ?? device.kind, symbol: device.symbol, isSelected: true
							) { bluetooth.toggle(device) }
						}
					}
				}
				if !paired.isEmpty {
					Section("Paired") {
						ForEach(paired) { device in
							ListItem(title: device.name, subtitle: status(device), symbol: device.symbol) {
								bluetooth.toggle(device)
							}
						}
					}
				}
			}
			FooterLink("Bluetooth Settings…") {
				NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!)
			}
		}
	}

	private var summary: String? {
		guard bluetooth.isOn else { return nil }
		let n = bluetooth.connected.count
		return n == 0 ? "No devices connected" : "\(n) connected"
	}

	private func status(_ device: BluetoothDevice) -> String {
		if bluetooth.connecting.contains(device.id) { return "Connecting…" }
		if bluetooth.failed.contains(device.id) { return "Couldn't connect" }
		return device.kind
	}
}
