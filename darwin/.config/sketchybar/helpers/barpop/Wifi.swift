import AppKit
import CoreLocation
import CoreWLAN
import Foundation
import Observation
import SystemConfiguration

struct WifiNetwork: Identifiable, Sendable {
	let ssid: String
	// nil when it isn't in the last scan.
	let rssi: Int?
	let secure: Bool
	let known: Bool

	var id: String { ssid }
}

// The Wi-Fi interface, sampled each second while the popup is open. macOS
// hides network names from apps without Location access, so the connected
// name falls back to ipconfig until that is granted.
@MainActor
@Observable
final class Wifi {
	static let samples = 30

	private(set) var power = false
	private(set) var connected = false
	private(set) var ssid: String?
	private(set) var rssi = 0
	private(set) var channel: Int?
	private(set) var band: String?
	private(set) var secure = false
	private(set) var ip: String?
	private(set) var router: String?
	private(set) var hostname: String?
	private(set) var download = [Double](repeating: 0, count: samples)
	private(set) var upload = [Double](repeating: 0, count: samples)
	private(set) var networks: [WifiNetwork] = []
	private(set) var scanning = false

	@ObservationIgnored private var counters: (rx: UInt32, tx: UInt32, at: Date)?
	@ObservationIgnored private var namedSSID: String?
	@ObservationIgnored private var lastScan = Date.distantPast
	@ObservationIgnored private var sampledAt = Date.distantPast
	@ObservationIgnored private let location = LocationGate()

	init() {
		location.changed = { [weak self] in self?.nameChanged() }
		Task { await sample() }
	}

	var signal: Double { Self.level(rssi) }

	// 0…1 from -90 dBm (barely there) to -50 dBm (full).
	nonisolated static func level(_ rssi: Int) -> Double { min(max(Double(rssi + 90) / 40, 0), 1) }

	func monitor() async {
		location.requestOnce()
		counters = nil
		namedSSID = nil
		download = Array(repeating: 0, count: Self.samples)
		upload = download
		while !Task.isCancelled {
			await sample()
			try? await Task.sleep(for: .seconds(1))
		}
	}

	func setPower(_ on: Bool) {
		Task {
			await Task.detached { try? CWWiFiClient.shared().interface()?.setPower(on) }.value
			await sample()
		}
	}

	// Joins with the keychain's password where macOS lets us read it;
	// otherwise, or if joining fails, hands over to Wi-Fi Settings.
	func join(_ network: WifiNetwork) {
		Task {
			let joined = await Task.detached { Self.associate(network.ssid) }.value
			if !joined { Self.openSettings() }
			await sample()
		}
	}

	static func openSettings() {
		NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension")!)
	}

	private func nameChanged() {
		namedSSID = nil
		lastScan = .distantPast
	}

	private func sample() async {
		let s = await Task.detached { Self.read() }.value
		// Reads can finish out of order (a toggle overlapping the tick).
		guard s.at > sampledAt else { return }
		sampledAt = s.at
		let wasConnected = connected
		power = s.power
		connected = s.connected
		rssi = s.rssi
		channel = s.channel
		band = s.band
		secure = s.secure
		ip = s.ip
		router = s.router
		hostname = s.hostname
		if connected != wasConnected { namedSSID = nil }
		if let name = s.ssid {
			ssid = name
		} else if connected {
			if namedSSID == nil { namedSSID = await Self.summarySSID(s.interface) }
			ssid = namedSSID
		} else {
			ssid = nil
		}
		record(s)
		if power && !connected && !scanning && Date().timeIntervalSince(lastScan) > 15 { scan(s.interface) }
	}

	private func record(_ s: Sample) {
		defer { counters = s.counters.map { ($0.rx, $0.tx, s.at) } }
		guard let prev = counters, let now = s.counters else { return }
		let dt = max(s.at.timeIntervalSince(prev.at), 0.1)
		// The link counters are 32-bit and wrap.
		download = Array((download + [Double(now.rx &- prev.rx) / dt]).suffix(Self.samples))
		upload = Array((upload + [Double(now.tx &- prev.tx) / dt]).suffix(Self.samples))
	}

	private func scan(_ interface: String) {
		scanning = true
		Task {
			let known = await Self.preferred(interface)
			let cached = await Task.detached { Self.cached() }.value
			if !cached.isEmpty { networks = Self.merge(cached, known: known) }
			let found = await Task.detached { Self.scanNetworks() }.value
			lastScan = Date()
			scanning = false
			networks = Self.merge(found, known: known)
		}
	}

	private struct Sample: Sendable {
		var at = Date()
		var interface = "en0"
		var power = false
		var connected = false
		var ssid: String?
		var rssi = 0
		var channel: Int?
		var band: String?
		var secure = false
		var ip: String?
		var router: String?
		var hostname: String?
		var counters: (rx: UInt32, tx: UInt32)?
	}

	private nonisolated static func read() -> Sample {
		var s = Sample()
		guard let wifi = CWWiFiClient.shared().interface() else { return s }
		s.interface = wifi.interfaceName ?? s.interface
		s.power = wifi.powerOn()
		if let ch = wifi.wlanChannel() {
			s.connected = true
			s.channel = ch.channelNumber
			s.band =
				switch ch.channelBand {
				case .band2GHz: "2.4 GHz"
				case .band5GHz: "5 GHz"
				case .band6GHz: "6 GHz"
				default: nil
				}
		}
		s.ssid = wifi.ssid()
		s.rssi = wifi.rssiValue()
		s.secure = wifi.security() != .none
		let store = SCDynamicStoreCreate(nil, "barpop" as CFString, nil, nil)
		if let store {
			s.hostname = (SCDynamicStoreCopyLocalHostName(store) as String?).map { "\($0).local" }
			let services = SCDynamicStoreCopyMultiple(store, nil, ["State:/Network/Service/.*/IPv4"] as CFArray)
			let ipv4 = (services as? [String: [String: Any]])?.values.first { $0["InterfaceName"] as? String == s.interface }
			s.ip = (ipv4?["Addresses"] as? [String])?.first
			s.router = ipv4?["Router"] as? String
		}
		s.counters = linkCounters(s.interface)
		return s
	}

	private nonisolated static func linkCounters(_ interface: String) -> (rx: UInt32, tx: UInt32)? {
		var list: UnsafeMutablePointer<ifaddrs>?
		guard getifaddrs(&list) == 0, let first = list else { return nil }
		defer { freeifaddrs(list) }
		for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
			let a = p.pointee
			guard let addr = a.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK), String(cString: a.ifa_name) == interface,
				let data = a.ifa_data?.assumingMemoryBound(to: if_data.self)
			else { continue }
			return (data.pointee.ifi_ibytes, data.pointee.ifi_obytes)
		}
		return nil
	}

	private nonisolated static func summarySSID(_ interface: String) async -> String? {
		let out = await Shell.output("ipconfig", "getsummary", interface)
		return out.split(separator: "\n").lazy
			.map { $0.trimmingCharacters(in: .whitespaces) }
			.first { $0.hasPrefix("SSID : ") }
			.map { String($0.dropFirst(7)) }
	}

	private nonisolated static func preferred(_ interface: String) async -> [String] {
		let out = await Shell.output("networksetup", "-listpreferredwirelessnetworks", interface)
		return out.split(separator: "\n").dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
	}

	private nonisolated static func scanNetworks() -> [WifiNetwork] {
		let found = (try? CWWiFiClient.shared().interface()?.scanForNetworks(withName: nil)) ?? []
		return networks(found)
	}

	private nonisolated static func cached() -> [WifiNetwork] {
		networks(CWWiFiClient.shared().interface()?.cachedScanResults() ?? [])
	}

	private nonisolated static func networks(_ found: Set<CWNetwork>) -> [WifiNetwork] {
		found.compactMap { n in
			n.ssid.map { WifiNetwork(ssid: $0, rssi: n.rssiValue, secure: !n.supportsSecurity(.none), known: false) }
		}
	}

	// Strongest first, one entry per name. Without Location access the scan
	// has no names, so the saved networks are listed on their own.
	private static func merge(_ found: [WifiNetwork], known: [String]) -> [WifiNetwork] {
		var best: [String: WifiNetwork] = [:]
		for n in found where (best[n.ssid]?.rssi ?? .min) < (n.rssi ?? .min) { best[n.ssid] = n }
		let inRange = best.values.sorted { ($0.rssi ?? .min) > ($1.rssi ?? .min) }
		let saved = Set(known)
		let knownNearby = inRange.filter { saved.contains($0.ssid) }.map {
			WifiNetwork(ssid: $0.ssid, rssi: $0.rssi, secure: $0.secure, known: true)
		}
		let knownList =
			found.isEmpty ? known.prefix(5).map { WifiNetwork(ssid: $0, rssi: nil, secure: true, known: true) } : knownNearby
		return Array(knownList.prefix(5)) + Array(inRange.filter { !saved.contains($0.ssid) }.prefix(6))
	}

	private nonisolated static func associate(_ ssid: String) -> Bool {
		guard let wifi = CWWiFiClient.shared().interface() else { return false }
		let cached = Array(wifi.cachedScanResults() ?? []).filter { $0.ssid == ssid }
		let pool = cached.isEmpty ? Array((try? wifi.scanForNetworks(withName: ssid)) ?? []) : cached
		guard let network = pool.max(by: { $0.rssiValue < $1.rssiValue }) else { return false }
		var password: String?
		if !network.supportsSecurity(.none) {
			var found: NSString?
			guard CWKeychainFindWiFiPassword(.system, Data(ssid.utf8), &found) == errSecSuccess, let found else {
				return false
			}
			password = found as String
		}
		return (try? wifi.associate(to: network, password: password)) != nil
	}
}

// Asks for Location once, the first time the popup opens, and reports
// when access changes so network names can be read.
@MainActor
private final class LocationGate: NSObject, CLLocationManagerDelegate {
	private let manager = CLLocationManager()
	var changed: @MainActor () -> Void = {}

	override init() {
		super.init()
		manager.delegate = self
	}

	func requestOnce() {
		if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
	}

	nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		MainActor.assumeIsolated { changed() }
	}
}
