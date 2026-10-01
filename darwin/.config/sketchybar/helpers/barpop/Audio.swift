import AudioToolbox
import CoreAudio
import Foundation
import Observation

struct OutputDevice: Identifiable, Equatable {
	let id: AudioObjectID
	let name: String
	let transport: UInt32

	var symbol: String {
		switch transport {
		case kAudioDeviceTransportTypeBuiltIn: return "laptopcomputer"
		case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
		case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "display"
		case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
		case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate: return "waveform"
		default: return "hifispeaker"
		}
	}

	var kind: String {
		switch transport {
		case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
		case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth"
		case kAudioDeviceTransportTypeHDMI: return "HDMI"
		case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
		case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
		case kAudioDeviceTransportTypeUSB: return "USB"
		case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
		case kAudioDeviceTransportTypeVirtual: return "Virtual device"
		case kAudioDeviceTransportTypeAggregate: return "Aggregate device"
		default: return "Output"
		}
	}
}

// The default output device's volume and mute, and the devices to pick from.
// Everything updates from CoreAudio listeners, so external changes (keys,
// Control Center) show up while the popup is open.
@MainActor
@Observable
final class Audio {
	var volume: Double = 0
	var muted = false
	var hasVolume = false
	var hasMute = false
	var devices: [OutputDevice] = []
	var current: AudioObjectID = 0

	@ObservationIgnored private let system = AudioObjectID(kAudioObjectSystemObject)
	@ObservationIgnored private var watched: AudioObjectID = 0
	@ObservationIgnored private var levelListener: AudioObjectPropertyListenerBlock?
	private static let levelSelectors = [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute]

	init() {
		listen(system, kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in self?.refreshDevice() }
		listen(system, kAudioHardwarePropertyDevices) { [weak self] in self?.refreshDevices() }
		refreshDevices()
		refreshDevice()
	}

	func setVolume(_ value: Double) {
		var v = Float32(min(max(value, 0), 1))
		guard hasVolume, set(current, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, &v) else { return }
		volume = Double(v)
		if muted && v > 0 { setMuted(false) }
	}

	func setMuted(_ value: Bool) {
		var m: UInt32 = value ? 1 : 0
		guard hasMute, set(current, kAudioDevicePropertyMute, &m) else { return }
		muted = value
	}

	func select(_ device: OutputDevice) {
		var id = device.id
		var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
		AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id)
	}

	var currentName: String { devices.first { $0.id == current }?.name ?? "Output" }

	private func refreshDevice() {
		var id = AudioObjectID(0)
		_ = get(system, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, &id)
		current = id
		if watched != id { watchLevel(id) }
		refreshLevel()
	}

	private func watchLevel(_ id: AudioObjectID) {
		if let block = levelListener {
			for selector in Self.levelSelectors {
				var addr = address(selector, kAudioDevicePropertyScopeOutput)
				AudioObjectRemovePropertyListenerBlock(watched, &addr, .main, block)
			}
		}
		let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
			MainActor.assumeIsolated { self?.refreshLevel() }
		}
		for selector in Self.levelSelectors {
			var addr = address(selector, kAudioDevicePropertyScopeOutput)
			if AudioObjectHasProperty(id, &addr) { AudioObjectAddPropertyListenerBlock(id, &addr, .main, block) }
		}
		watched = id
		levelListener = block
	}

	// A device without a volume control plays at full level.
	private func refreshLevel() {
		var v = Float32(0)
		hasVolume = get(current, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput, &v)
		volume = hasVolume ? Double(v) : 1
		var m = UInt32(0)
		hasMute = get(current, kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput, &m)
		muted = hasMute && m != 0
	}

	private func refreshDevices() {
		var addr = address(kAudioHardwarePropertyDevices)
		var size = UInt32(0)
		AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size)
		var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
		AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids)
		devices = ids.compactMap { id in
			guard canBeDefault(id) else { return nil }
			return OutputDevice(id: id, name: name(id), transport: transport(id))
		}
	}

	private func canBeDefault(_ id: AudioObjectID) -> Bool {
		var v = UInt32(0)
		return get(id, kAudioDevicePropertyDeviceCanBeDefaultDevice, kAudioDevicePropertyScopeOutput, &v) && v != 0
	}

	private func name(_ id: AudioObjectID) -> String {
		var name: Unmanaged<CFString>?
		guard get(id, kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, &name), let n = name else {
			return "Unknown"
		}
		return n.takeRetainedValue() as String
	}

	private func transport(_ id: AudioObjectID) -> UInt32 {
		var t = UInt32(0)
		_ = get(id, kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal, &t)
		return t
	}

	private func get<T: BitwiseCopyable>(
		_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ value: inout T
	) -> Bool {
		var addr = address(selector, scope)
		var size = UInt32(MemoryLayout<T>.size)
		return AudioObjectHasProperty(id, &addr) && AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr
	}

	private func set<T: BitwiseCopyable>(
		_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: inout T
	) -> Bool {
		var addr = address(selector, kAudioDevicePropertyScopeOutput)
		return AudioObjectSetPropertyData(id, &addr, 0, nil, UInt32(MemoryLayout<T>.size), &value) == noErr
	}

	private func address(
		_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
	) -> AudioObjectPropertyAddress {
		AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
	}

	private func listen(
		_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
		_ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ handler: @escaping @MainActor () -> Void
	) {
		var addr = address(selector, scope)
		AudioObjectAddPropertyListenerBlock(id, &addr, .main) { _, _ in MainActor.assumeIsolated { handler() } }
	}
}
