import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import Observation

struct AudioDevice: Identifiable, Equatable {
	let id: AudioObjectID
	let name: String
	let transport: UInt32
	let isInput: Bool

	var symbol: String { isInput ? inputSymbol : outputSymbol }

	private var inputSymbol: String {
		switch transport {
		case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
			return name.localizedCaseInsensitiveContains("AirPods") ? "airpods" : "headphones"
		case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "display"
		case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate: return "waveform"
		default: return "mic"
		}
	}

	private var outputSymbol: String {
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
		default: return isInput ? "Input" : "Output"
		}
	}
}

// The default output device's volume and mute, the default input's gain,
// and the devices to pick from. Everything updates from CoreAudio listeners,
// so external changes (keys, Control Center) show up while the popup is open.
@MainActor
@Observable
final class Audio {
	var volume: Double = 0
	var muted = false
	var hasVolume = false
	var hasMute = false
	var devices: [AudioDevice] = []
	var current: AudioObjectID = 0
	var inputVolume: Double = 0
	var hasInputVolume = false
	var inputs: [AudioDevice] = []
	var currentInput: AudioObjectID = 0
	// The default input's level, 0…1, while the popup is open.
	var inputLevel: Double = 0
	var micAccess = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

	@ObservationIgnored private let system = AudioObjectID(kAudioObjectSystemObject)
	@ObservationIgnored private var outputWatch = Watch()
	@ObservationIgnored private var inputWatch = Watch()
	// Inputs expose gain as the virtual main volume or only as the main
	// element's scalar, depending on the driver.
	@ObservationIgnored private var inputSelector: AudioObjectPropertySelector?
	private static let levelSelectors = [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute]
	private static let gainSelectors = [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyVolumeScalar]

	private struct Watch {
		var id: AudioObjectID = 0
		var block: AudioObjectPropertyListenerBlock?
	}

	init() {
		listen(system, kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in self?.refreshDevice() }
		listen(system, kAudioHardwarePropertyDefaultInputDevice) { [weak self] in self?.refreshInput() }
		listen(system, kAudioHardwarePropertyDevices) { [weak self] in self?.refreshDevices() }
		refreshDevices()
		refreshDevice()
		refreshInput()
	}

	func setVolume(_ value: Double) {
		var v = Float32(min(max(value, 0), 1))
		guard hasVolume, set(current, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput, &v)
		else { return }
		volume = Double(v)
		if muted && v > 0 { setMuted(false) }
	}

	func setMuted(_ value: Bool) {
		var m: UInt32 = value ? 1 : 0
		guard hasMute, set(current, kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput, &m) else { return }
		muted = value
	}

	func setInputVolume(_ value: Double) {
		var v = Float32(min(max(value, 0), 1))
		guard hasInputVolume, let selector = inputSelector, set(currentInput, selector, kAudioDevicePropertyScopeInput, &v)
		else { return }
		inputVolume = Double(v)
	}

	func select(_ device: AudioDevice) {
		var id = device.id
		var addr = address(device.isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice)
		AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id)
	}

	// Meters the default input from open until close, on a fresh engine for
	// each device: one built for the previous device stops when it changes.
	func meterInput() async {
		if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
			_ = await AVCaptureDevice.requestAccess(for: .audio)
		}
		micAccess = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
		guard micAccess else { return }
		let meter = InputMeter()
		var metered: AudioObjectID?
		while !Task.isCancelled {
			if metered != currentInput {
				metered = currentInput
				await Task.detached { meter.restart() }.value
			}
			let now = meter.take()
			// Rises at once, falls back over a few frames.
			inputLevel = now > inputLevel ? now : inputLevel * 0.75 + now * 0.25
			try? await Task.sleep(for: .milliseconds(40))
		}
		await Task.detached { meter.stop() }.value
		inputLevel = 0
	}

	var currentName: String { devices.first { $0.id == current }?.name ?? "Output" }

	private func refreshDevice() {
		var id = AudioObjectID(0)
		_ = get(system, kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, &id)
		current = id
		if outputWatch.id != id {
			watch(&outputWatch, id, Self.levelSelectors, kAudioDevicePropertyScopeOutput) { [weak self] in self?.refreshLevel() }
		}
		refreshLevel()
	}

	private func refreshInput() {
		var id = AudioObjectID(0)
		_ = get(system, kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal, &id)
		currentInput = id
		if inputWatch.id != id {
			inputSelector = Self.gainSelectors.first { selector in
				var addr = address(selector, kAudioDevicePropertyScopeInput)
				var settable = DarwinBoolean(false)
				return AudioObjectHasProperty(id, &addr) && AudioObjectIsPropertySettable(id, &addr, &settable) == noErr
					&& settable.boolValue
			}
			watch(&inputWatch, id, inputSelector.map { [$0] } ?? [], kAudioDevicePropertyScopeInput) { [weak self] in
				self?.refreshInputLevel()
			}
		}
		refreshInputLevel()
	}

	// Moves the listeners on the previous device to the new one.
	private func watch(
		_ w: inout Watch, _ id: AudioObjectID, _ selectors: [AudioObjectPropertySelector], _ scope: AudioObjectPropertyScope,
		_ handler: @escaping @MainActor () -> Void
	) {
		if let block = w.block {
			for selector in Self.levelSelectors + Self.gainSelectors {
				var addr = address(selector, scope)
				AudioObjectRemovePropertyListenerBlock(w.id, &addr, .main, block)
			}
		}
		let block: AudioObjectPropertyListenerBlock = { _, _ in MainActor.assumeIsolated { handler() } }
		for selector in selectors {
			var addr = address(selector, scope)
			if AudioObjectHasProperty(id, &addr) { AudioObjectAddPropertyListenerBlock(id, &addr, .main, block) }
		}
		w = Watch(id: id, block: block)
	}

	private func refreshInputLevel() {
		var v = Float32(0)
		hasInputVolume = inputSelector.map { get(currentInput, $0, kAudioDevicePropertyScopeInput, &v) } ?? false
		inputVolume = hasInputVolume ? Double(v) : 1
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
		let list = { (input: Bool) in
			ids.compactMap { id in
				self.canBeDefault(id, input: input)
					? AudioDevice(id: id, name: self.name(id), transport: self.transport(id), isInput: input) : nil
			}
		}
		devices = list(false)
		inputs = list(true)
	}

	private func canBeDefault(_ id: AudioObjectID, input: Bool) -> Bool {
		let scope = input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
		var addr = address(kAudioDevicePropertyStreams, scope)
		var size = UInt32(0)
		guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return false }
		var v = UInt32(0)
		return get(id, kAudioDevicePropertyDeviceCanBeDefaultDevice, scope, &v) && v != 0
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
		_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope, _ value: inout T
	) -> Bool {
		var addr = address(selector, scope)
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

// Taps the default input on the audio thread and keeps its loudest recent
// RMS as 0…1 over -60…0 dB.
private final class InputMeter: @unchecked Sendable {
	private let lock = NSLock()
	private var engine: AVAudioEngine?
	private var latest = 0.0

	// The loudest buffer since the last call, so peaks between reads count.
	func take() -> Double {
		lock.withLock {
			defer { latest = 0 }
			return latest
		}
	}

	func restart() {
		stop()
		let engine = AVAudioEngine()
		let input = engine.inputNode
		let format = input.outputFormat(forBus: 0)
		guard format.channelCount > 0, format.sampleRate > 0 else { return }
		input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
			guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
			var sum: Float = 0
			for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
			let db = 20 * log10(max(sqrt(sum / Float(buffer.frameLength)), 1e-6))
			let level = Double(min(max((db + 60) / 60, 0), 1))
			self?.lock.withLock { self?.latest = max(self?.latest ?? 0, level) }
		}
		do { try engine.start() } catch {
			input.removeTap(onBus: 0)
			return
		}
		lock.withLock { self.engine = engine }
	}

	func stop() {
		let engine = lock.withLock {
			defer { self.engine = nil; latest = 0 }
			return self.engine
		}
		engine?.inputNode.removeTap(onBus: 0)
		engine?.stop()
	}
}
