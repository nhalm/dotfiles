import Foundation
import IOBluetooth
import Observation

struct BluetoothDevice: Identifiable, Equatable {
	let id: String
	let name: String
	let kind: String
	let symbol: String
	let isConnected: Bool
	let battery: String?
}

// Power and connections through IOBluetooth; power through the preference
// calls blueutil uses. Device types and batteries come from system_profiler,
// the one source that has them for LE and non-Apple devices too.
@MainActor
@Observable
final class Bluetooth {
	private(set) var isOn = false
	private(set) var devices: [BluetoothDevice] = []
	private(set) var connecting: Set<String> = []
	private(set) var failed: Set<String> = []

	@ObservationIgnored private var profile: [String: Profile] = [:]
	@ObservationIgnored private var loading: Task<Void, Never>?
	@ObservationIgnored private lazy var observer = Observer { [weak self] in self?.handle($0) }

	init() {
		for name in [NSNotification.Name.IOBluetoothHostControllerPoweredOn, .IOBluetoothHostControllerPoweredOff] {
			NotificationCenter.default.addObserver(observer, selector: #selector(Observer.power), name: name, object: nil)
		}
		IOBluetoothDevice.register(forConnectNotifications: observer, selector: #selector(Observer.connected(_:device:)))
		refresh()
	}

	var connected: [BluetoothDevice] { devices.filter(\.isConnected) }
	var paired: [BluetoothDevice] { devices.filter { !$0.isConnected } }

	func refresh() {
		rebuild()
		loadProfile()
	}

	func setPower(_ on: Bool) {
		isOn = on
		DispatchQueue.global().async { Power.set(on) }
	}

	func toggle(_ device: BluetoothDevice) {
		guard let d = IOBluetoothDevice(addressString: device.id), !connecting.contains(device.id) else { return }
		if device.isConnected {
			d.closeConnection()
			return
		}
		failed.remove(device.id)
		if d.openConnection(observer) == kIOReturnSuccess {
			connecting.insert(device.id)
		} else {
			fail(device.id)
		}
	}

	private func handle(_ event: Observer.Event) {
		switch event {
		case .power:
			let on = Power.get()
			Shell.trigger("bluetooth_change", ["POWER": on ? "on" : "off"])
			if !on { connecting = [] }
			rebuild()
		case .connected:
			refresh()
			// Batteries reach system_profiler a moment after the link comes up.
			DispatchQueue.main.asyncAfter(deadline: .now() + 3) { MainActor.assumeIsolated { self.loadProfile() } }
		case .disconnected:
			rebuild()
		case .completed(let address, let ok):
			connecting.remove(address)
			if !ok { fail(address) }
			rebuild()
		}
	}

	private func fail(_ address: String) {
		failed.insert(address)
		DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
			MainActor.assumeIsolated { _ = self.failed.remove(address) }
		}
	}

	private func rebuild() {
		isOn = Power.get()
		let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
		devices = paired.compactMap { d in
			guard let address = d.addressString?.lowercased() else { return nil }
			let p = profile[address]
			let kind = Kind(minorType: p?.minorType, device: d)
			let isConnected = isOn && d.isConnected()
			guard isConnected || kind != .other else { return nil }
			let name = d.name ?? p?.name ?? address
			return BluetoothDevice(
				id: address, name: name, kind: kind.label, symbol: kind.symbol(name), isConnected: isConnected,
				battery: isConnected ? p?.battery : nil)
		}
		.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
	}

	private func loadProfile() {
		guard loading == nil else { return }
		loading = Task {
			defer { loading = nil }
			let json = await Shell.output("system_profiler", "SPBluetoothDataType", "-json")
			profile = Profile.parse(json)
			rebuild()
		}
	}
}

// IOBluetooth calls back on its own queues when CoreBluetooth reports LE
// links, so every event hops to the main actor.
private final class Observer: NSObject, Sendable {
	enum Event: Sendable {
		case power, connected, disconnected
		case completed(String, ok: Bool)
	}

	let send: @MainActor @Sendable (Event) -> Void

	init(_ send: @escaping @MainActor @Sendable (Event) -> Void) { self.send = send }

	private func post(_ event: Event) {
		let send = send
		Task { @MainActor in send(event) }
	}

	@objc func power(_ note: Notification) { post(.power) }

	@objc func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
		device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
		post(.connected)
	}

	@objc func disconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
		note.unregister()
		post(.disconnected)
	}

	@objc func connectionComplete(_ device: IOBluetoothDevice, status: IOReturn) {
		post(.completed(device.addressString?.lowercased() ?? "", ok: status == kIOReturnSuccess))
	}
}

// IOBluetooth exports these but leaves them out of its headers.
private enum Power {
	private typealias Get = @convention(c) () -> Int32
	private typealias SetPower = @convention(c) (Int32) -> Void
	private nonisolated(unsafe) static let lib = dlopen(
		"/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_NOW)

	static func get() -> Bool {
		guard let f = dlsym(lib, "IOBluetoothPreferenceGetControllerPowerState") else { return false }
		return unsafeBitCast(f, to: Get.self)() != 0
	}

	static func set(_ on: Bool) {
		guard let f = dlsym(lib, "IOBluetoothPreferenceSetControllerPowerState") else { return }
		unsafeBitCast(f, to: SetPower.self)(on ? 1 : 0)
	}
}

private struct Profile {
	let name: String
	let minorType: String?
	let battery: String?

	// Keyed by address in IOBluetooth's lowercase, dashed form.
	static func parse(_ json: String) -> [String: Profile] {
		guard let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
			let info = (root["SPBluetoothDataType"] as? [[String: Any]])?.first
		else { return [:] }
		var out: [String: Profile] = [:]
		for key in ["device_connected", "device_not_connected"] {
			for entry in info[key] as? [[String: [String: String]]] ?? [] {
				for (name, v) in entry {
					guard let address = v["device_address"] else { continue }
					let parts = [("", "Main"), ("L ", "Left"), ("R ", "Right"), ("Case ", "Case")].compactMap { label, side in
						v["device_batteryLevel\(side)"].map { label + $0 }
					}
					out[address.lowercased().replacingOccurrences(of: ":", with: "-")] = Profile(
						name: name, minorType: v["device_minorType"],
						battery: parts.isEmpty ? nil : parts.joined(separator: " · "))
				}
			}
		}
		return out
	}
}

private enum Kind {
	case headphones, headset, speaker, keyboard, mouse, trackpad, gamepad, other

	init(minorType: String?, device: IOBluetoothDevice) {
		if let t = minorType?.lowercased() {
			let match: [(String, Kind)] = [
				("headphone", .headphones), ("headset", .headset), ("hands", .headset), ("speaker", .speaker),
				("keyboard", .keyboard), ("mouse", .mouse), ("pointing", .mouse), ("trackpad", .trackpad),
				("game", .gamepad), ("joystick", .gamepad),
			]
			if let kind = match.first(where: { t.contains($0.0) })?.1 {
				self = kind
				return
			}
		}
		let minor = device.deviceClassMinor
		switch device.deviceClassMajor {
		case UInt32(kBluetoothDeviceClassMajorAudio):
			switch minor {
			case 1, 2: self = .headset
			case 5, 7, 10: self = .speaker
			default: self = .headphones
			}
		case UInt32(kBluetoothDeviceClassMajorPeripheral):
			if minor & 0x0f == 1 || minor & 0x0f == 2 {
				self = .gamepad
			} else {
				self = minor & 0x30 == 0x20 ? .mouse : minor & 0x30 != 0 ? .keyboard : .other
			}
		default: self = .other
		}
	}

	var label: String {
		switch self {
		case .headphones: "Headphones"
		case .headset: "Headset"
		case .speaker: "Speaker"
		case .keyboard: "Keyboard"
		case .mouse: "Mouse"
		case .trackpad: "Trackpad"
		case .gamepad: "Game controller"
		case .other: "Device"
		}
	}

	func symbol(_ name: String) -> String {
		switch self {
		case .headphones:
			if name.contains("AirPods Max") { return "airpods.max" }
			if name.contains("AirPods Pro") { return "airpods.pro" }
			return name.contains("AirPods") ? "airpods" : "headphones"
		case .headset: return "headset"
		case .speaker: return "hifispeaker"
		case .keyboard: return "keyboard"
		case .mouse: return name.contains("Magic Mouse") ? "magicmouse" : "computermouse"
		case .trackpad: return "rectangle.and.hand.point.up.left"
		case .gamepad: return "gamecontroller"
		case .other: return "wave.3.right"
		}
	}
}
