import SwiftUI

struct WifiPopup: View {
	@Environment(Wifi.self) private var wifi

	var body: some View {
		PopupCard(width: .regular) {
			HeroHeader(
				eyebrow: "Wi-Fi", value: headline, subtitle: subtitle, style: .text, dimmed: !wifi.connected
			) {
				HeaderToggle(
					symbol: wifi.power ? "wifi" : "wifi.slash", variableValue: wifi.connected ? wifi.signal : nil,
					isOn: wifi.power, searching: wifi.power && !wifi.connected,
					label: wifi.power ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
				) { wifi.setPower(!wifi.power) }
			}
			if wifi.connected {
				StatGrid(columns: 2) {
					let down = rate(wifi.download.last ?? 0)
					let up = rate(wifi.upload.last ?? 0)
					StatTile(label: "Download", symbol: "arrow.down", value: down.value, unit: down.unit, live: true) {} footer: {
						Sparkline(values: wifi.download)
					}
					StatTile(label: "Upload", symbol: "arrow.up", value: up.value, unit: up.unit, live: true) {} footer: {
						Sparkline(values: wifi.upload, tone: .alt)
					}
				}
				Section("Details", trailing: "Click to copy") {
					CopyRow(
						"Signal", value: "\(wifi.rssi) dBm",
						symbol: "cellularbars", variableValue: wifi.signal)
					if let ip = wifi.ip { CopyRow("IP address", value: ip) }
					if let router = wifi.router { CopyRow("Router", value: router) }
					if let host = wifi.hostname { CopyRow("Hostname", value: host) }
				}
			} else if wifi.power {
				let known = wifi.networks.filter(\.known)
				let other = wifi.networks.filter { !$0.known }
				if !known.isEmpty {
					Section("Known networks") {
						ForEach(known) { network(known: true, $0) }
					}
				}
				if !other.isEmpty {
					Section("Other networks") {
						ForEach(other) { network(known: false, $0) }
					}
				}
			}
			FooterLink("Wi-Fi Settings…") { Wifi.openSettings() }
		}
		.whileOpen { await wifi.monitor() }
	}

	private var headline: String {
		if !wifi.power { return "Off" }
		return wifi.connected ? wifi.ssid ?? "Connected" : "Not connected"
	}

	private var subtitle: String {
		if !wifi.power { return "Turn on to join a network" }
		if !wifi.connected { return wifi.scanning ? "Searching for networks…" : "Choose a network" }
		return [wifi.secure ? "Secured" : "Open", wifi.band, wifi.channel.map { "Channel \($0)" }]
			.compactMap { $0 }.joined(separator: " · ")
	}

	private func network(known: Bool, _ n: WifiNetwork) -> some View {
		let weak = n.rssi.map { $0 < -75 } ?? false
		let subtitle =
			known
			? (weak ? "Saved · Weak signal" : "Saved")
			: (n.secure ? "Secured" : "Open")
		return ListItem(
			title: n.ssid, subtitle: subtitle, symbol: "wifi",
			variableValue: n.rssi.map(Wifi.level),
			trailingSymbol: n.secure ? "lock.fill" : nil, hoverChip: "Join"
		) { wifi.join(n) }
	}

	private func rate(_ bytes: Double) -> (value: String, unit: String) {
		if bytes >= 1_000_000 { return (String(format: "%.1f", bytes / 1_000_000), "MB/s") }
		if bytes >= 1_000 { return ("\(Int(bytes / 1_000))", "KB/s") }
		return ("\(Int(bytes))", "B/s")
	}
}
