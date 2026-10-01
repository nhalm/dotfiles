import AppKit
import IOKit
import IOKit.ps
import Observation

struct EnergyApp: Identifiable {
	let id: pid_t
	let name: String
	let icon: NSImage?
}

// The internal battery from IOKit power sources, updated as they change;
// health from AppleSmartBattery. Energy use is sampled with top on demand.
@MainActor
@Observable
final class Battery {
	var isPresent = false
	var percent = 0
	var onAC = false
	var isCharging = false
	var isCharged = false
	var minutesToEmpty: Int?
	var minutesToFull: Int?
	var condition: String?
	var maxCapacity: Int?
	var cycles: Int?
	var charger: String?
	var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
	var energy: [EnergyApp] = []

	var isLow: Bool { isPresent && !onAC && percent <= 20 }

	@ObservationIgnored private var sampling = false

	init() {
		refresh()
		let me = Unmanaged.passUnretained(self).toOpaque()
		let source = IOPSNotificationCreateRunLoopSource(
			{ ctx in
				guard let ctx else { return }
				MainActor.assumeIsolated { Unmanaged<Battery>.fromOpaque(ctx).takeUnretainedValue().refresh() }
			}, me)
		if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source.takeRetainedValue(), .defaultMode) }
		NotificationCenter.default.addObserver(
			forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated { self?.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
		}
	}

	// pmset needs root, so each change asks for an administrator password.
	func setLowPower(_ on: Bool) {
		Task {
			let script = "do shell script \"pmset -a lowpowermode \(on ? 1 : 0)\" with administrator privileges"
			_ = await Shell.output(["osascript", "-e", script], timeout: 120)
			lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
		}
	}

	// top needs two samples for power, about 1.5s; the last list stays up meanwhile.
	func sampleEnergy() {
		guard !sampling, !onAC else { return }
		sampling = true
		Task {
			let out = await Shell.output("top", "-l", "2", "-o", "power", "-stats", "pid,power", "-n", "20")
			sampling = false
			let rows = out.split(separator: "\n")
			let sample = rows.lastIndex { $0.hasPrefix("PID") }.map { rows[($0 + 1)...] } ?? []
			let apps = sample.compactMap { row -> EnergyApp? in
				let cols = row.split(separator: " ")
				guard cols.count >= 2, let pid = pid_t(cols[0]), let power = Double(cols[cols.count - 1]), power >= 1,
					let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular
				else { return nil }
				return EnergyApp(id: pid, name: app.localizedName ?? "App", icon: app.icon)
			}
			energy = Array(apps.prefix(3))
		}
	}

	func activate(_ app: EnergyApp) {
		NSRunningApplication(processIdentifier: app.id)?.activate()
	}

	private func refresh() {
		let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
		let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
		let battery = sources.lazy
			.compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
			.first { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }
		isPresent = battery != nil
		guard let battery else { return }
		let current = battery[kIOPSCurrentCapacityKey] as? Int ?? 0
		let max = battery[kIOPSMaxCapacityKey] as? Int ?? 100
		percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : 0
		onAC = battery[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
		isCharging = battery[kIOPSIsChargingKey] as? Bool ?? false
		isCharged = battery[kIOPSIsChargedKey] as? Bool ?? false
		minutesToEmpty = (battery[kIOPSTimeToEmptyKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
		minutesToFull = (battery[kIOPSTimeToFullChargeKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
		condition =
			switch battery[kIOPSBatteryHealthKey] as? String {
			case kIOPSGoodValue: "Normal"
			case kIOPSFairValue: "Fair"
			case kIOPSPoorValue: "Service Recommended"
			default: nil
			}
		if let failure = battery[kIOPSBatteryHealthConditionKey] as? String, !failure.isEmpty { condition = failure }
		if onAC, let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] {
			let watts = (adapter[kIOPSPowerAdapterWattsKey] as? Int).map { "\($0) W" }
			let name = adapter["Name"] as? String
			charger = [watts, name].compactMap { $0 }.joined(separator: " · ")
		} else {
			charger = nil
		}
		readSmartBattery()
	}

	private func readSmartBattery() {
		let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
		guard service != 0 else { return }
		defer { IOObjectRelease(service) }
		func int(_ key: String) -> Int? {
			IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
		}
		cycles = int("CycleCount")
		if let raw = int("AppleRawMaxCapacity"), let design = int("DesignCapacity"), design > 0 {
			maxCapacity = Int((Double(raw) / Double(design) * 100).rounded())
		}
	}
}
