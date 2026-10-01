import AppKit
import CoreLocation
import CoreWLAN
import Foundation
import Network
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

// How the Mac reaches an iPhone's Personal Hotspot.
enum Tether: String, Sendable {
	case wifi = "Wi-Fi"
	case usb = "USB"
	case bluetooth = "Bluetooth"
}

// The Wi-Fi interface, sampled each second while the popup is open. macOS
// hides network names from apps without Location access, so the connected
// name falls back to ipconfig until that is granted. The network path is
// watched all the time, so the bar knows when it is on a Personal Hotspot.
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
	private(set) var hostname: String?
	private(set) var download = [Double](repeating: 0, count: samples)
	private(set) var upload = [Double](repeating: 0, count: samples)
	private(set) var networks: [WifiNetwork] = []
	private(set) var scanning = false
	private(set) var tether: Tether?
	// The hotspot's device: its network name over Wi-Fi.
	private(set) var tetherName: String?

	@ObservationIgnored private var counters: (rx: UInt32, tx: UInt32, at: Date)?
	@ObservationIgnored private var namedSSID: String?
	@ObservationIgnored private var lastScan = Date.distantPast
	@ObservationIgnored private var sampledAt = Date.distantPast
	@ObservationIgnored private let location = LocationGate()
	@ObservationIgnored private let paths = NWPathMonitor()
	@ObservationIgnored private var pathChanges = 0
	// Where traffic goes when it isn't the Wi-Fi interface (USB, Bluetooth).
	@ObservationIgnored private var link: String?

	init() {
		location.changed = { [weak self] in self?.nameChanged() }
		paths.pathUpdateHandler = { [weak self] path in
			MainActor.assumeIsolated { self?.pathChanged(path) }
		}
		paths.start(queue: .main)
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

	// Leaves the network with Wi-Fi still on, e.g. a Personal Hotspot; macOS
	// may rejoin a known one.
	func disconnect() {
		Task {
			await Task.detached { CWWiFiClient.shared().interface()?.disassociate() }.value
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

	// Tells the bar's Wi-Fi item whether it is on a Personal Hotspot.
	func announce() {
		Shell.trigger(
			"barpop_network",
			["HOTSPOT": tether == nil ? "0" : "1", "DEVICE": tetherName ?? "", "VIA": tether?.rawValue ?? ""])
	}

	private func pathChanged(_ path: NWPath) {
		pathChanges += 1
		let change = pathChanges
		Task {
			let found = await Self.tether(path)
			guard change == pathChanges else { return }
			let interface = found.flatMap { $0.via == .wifi ? nil : $0.interface }
			if interface != link {
				link = interface
				counters = nil
			}
			guard found?.via != tether || found?.name != tetherName else { return }
			tether = found?.via
			tetherName = found?.name
			announce()
		}
	}

	private func nameChanged() {
		namedSSID = nil
		lastScan = .distantPast
	}

	private func sample() async {
		let link = link
		let s = await Task.detached { Self.read(link: link) }.value
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
		var hostname: String?
		var counters: (rx: UInt32, tx: UInt32)?
	}

	private nonisolated static func read(link: String?) -> Sample {
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
		let interface = link ?? s.interface
		let store = SCDynamicStoreCreate(nil, "barpop" as CFString, nil, nil)
		if let store {
			s.hostname = (SCDynamicStoreCopyLocalHostName(store) as String?).map { "\($0).local" }
			let services = SCDynamicStoreCopyMultiple(store, nil, ["State:/Network/Service/.*/IPv4"] as CFArray)
			let ipv4 = (services as? [String: [String: Any]])?.values.first { $0["InterfaceName"] as? String == interface }
			s.ip = (ipv4?["Addresses"] as? [String])?.first
		}
		s.counters = linkCounters(interface)
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
		await summary(interface)["SSID"]
	}

	// ipconfig's top-level "KEY : value" lines; nested ones are indented further.
	private nonisolated static func summary(_ interface: String) async -> [String: String] {
		let out = await Shell.output("ipconfig", "getsummary", interface)
		var fields: [String: String] = [:]
		for line in out.split(separator: "\n") where line.hasPrefix("  ") && !line.hasPrefix("   ") {
			let parts = line.split(separator: " : ", maxSplits: 1)
			if parts.count == 2 { fields[parts[0].trimmingCharacters(in: .whitespaces)] = String(parts[1]) }
		}
		return fields
	}

	// macOS marks the path expensive on a Personal Hotspot, however it is
	// reached. The interface carrying it says how; an iPhone's hotspot
	// BSSID is locally administered, which rules out a metered access point.
	private nonisolated static func tether(_ path: NWPath) async -> (via: Tether, name: String, interface: String)? {
		guard path.status == .satisfied, path.isExpensive else { return nil }
		let ports = (SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []).reduce(into: [String: SCNetworkInterface]()) {
			if let name = SCNetworkInterfaceGetBSDName($1) as String? { $0[name] = $1 }
		}
		// A VPN's utun is first when it is up; the hardware under it is what counts.
		guard let interface = path.availableInterfaces.lazy.map(\.name).first(where: { ports[$0] != nil }),
			let port = ports[interface]
		else { return nil }
		let type = SCNetworkInterfaceGetInterfaceType(port)
		if type == kSCNetworkInterfaceTypeIEEE80211 {
			let fields = await summary(interface)
			if let bssid = fields["BSSID"], let octet = bssid.split(separator: ":").first.flatMap({ UInt8($0, radix: 16) }),
				octet & 0x02 == 0
			{ return nil }
			let ssid = CWWiFiClient.shared().interface(withName: interface)?.ssid() ?? fields["SSID"]
			return (.wifi, ssid ?? "iPhone", interface)
		}
		if type == kSCNetworkInterfaceTypeBluetooth { return (.bluetooth, "iPhone", interface) }
		let name = (SCNetworkInterfaceGetLocalizedDisplayName(port) as String?)?.replacingOccurrences(of: " USB", with: "")
		return (.usb, name ?? "iPhone", interface)
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
