import AudioToolbox
import CoreAudio
import Foundation

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
}

// The default output device's volume and mute, and the devices to pick from.
// Everything updates from CoreAudio listeners, so external changes (keys,
// Control Center) show up while the popup is open.
final class Audio: ObservableObject {
	@Published var volume: Double = 0
	@Published var muted = false
	@Published var devices: [OutputDevice] = []
	@Published var current: AudioObjectID = 0

	private let system = AudioObjectID(kAudioObjectSystemObject)
	private var watched: AudioObjectID = 0

	init() {
		listen(system, kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in self?.refreshDevice() }
		listen(system, kAudioHardwarePropertyDevices) { [weak self] in self?.refreshDevices() }
		refreshDevices()
		refreshDevice()
	}

	func setVolume(_ value: Double) {
		var v = Float32(min(max(value, 0), 1))
		var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
		AudioObjectSetPropertyData(current, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
		if muted && v > 0 { setMuted(false) }
		volume = Double(v)
	}

	func setMuted(_ value: Bool) {
		var m: UInt32 = value ? 1 : 0
		var addr = address(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
		AudioObjectSetPropertyData(current, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m)
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
		var size = UInt32(MemoryLayout<AudioObjectID>.size)
		var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
		AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id)
		current = id
		if watched != id {
			watched = id
			listen(id, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput) {
				[weak self] in self?.refreshLevel()
			}
			listen(id, kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput) { [weak self] in self?.refreshLevel() }
		}
		refreshLevel()
	}

	private func refreshLevel() {
		var v = Float32(0)
		var size = UInt32(MemoryLayout<Float32>.size)
		var addr = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
		if AudioObjectGetPropertyData(current, &addr, 0, nil, &size, &v) == noErr { volume = Double(v) }
		var m = UInt32(0)
		size = UInt32(MemoryLayout<UInt32>.size)
		addr = address(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
		if AudioObjectGetPropertyData(current, &addr, 0, nil, &size, &m) == noErr { muted = m != 0 }
	}

	private func refreshDevices() {
		var addr = address(kAudioHardwarePropertyDevices)
		var size = UInt32(0)
		AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size)
		var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
		AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids)
		devices = ids.compactMap { id in
			guard hasOutput(id) else { return nil }
			return OutputDevice(id: id, name: name(id), transport: transport(id))
		}
	}

	private func hasOutput(_ id: AudioObjectID) -> Bool {
		var addr = address(kAudioDevicePropertyStreams, kAudioDevicePropertyScopeOutput)
		var size = UInt32(0)
		AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size)
		return size > 0
	}

	private func name(_ id: AudioObjectID) -> String {
		var addr = address(kAudioObjectPropertyName)
		var name: Unmanaged<CFString>?
		var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
		guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name) == noErr, let n = name else {
			return "Unknown"
		}
		return n.takeRetainedValue() as String
	}

	private func transport(_ id: AudioObjectID) -> UInt32 {
		var addr = address(kAudioDevicePropertyTransportType)
		var t = UInt32(0)
		var size = UInt32(MemoryLayout<UInt32>.size)
		AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &t)
		return t
	}

	private func address(
		_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
	) -> AudioObjectPropertyAddress {
		AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
	}

	private func listen(
		_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
		_ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ handler: @escaping () -> Void
	) {
		var addr = address(selector, scope)
		AudioObjectAddPropertyListenerBlock(id, &addr, .main) { _, _ in handler() }
	}
}
