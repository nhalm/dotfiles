import Observation
import SwiftUI

// The matugen roles barpop draws with; the defaults match the bar's static
// TokyoNight table.
struct Roles: Equatable {
	var surface = Color(hex: 0x1a1b26)
	var surfaceContainer = Color(hex: 0x1f2335)
	var surfaceContainerHigh = Color(hex: 0x24283b)
	var surfaceContainerHighest = Color(hex: 0x292e42)
	var onSurface = Color(hex: 0xc0caf5)
	var onSurfaceVariant = Color(hex: 0x565f89)
	var primary = Color(hex: 0x7aa2f7)
	var onPrimary = Color(hex: 0x1a1b26)
	var primaryContainer = Color(hex: 0x3d59a1)
	var onPrimaryContainer = Color(hex: 0xc0caf5)
	var secondary = Color(hex: 0x7dcfff)
	var tertiary = Color(hex: 0xbb9af7)
	var error = Color(hex: 0xf7768e)
	var outlineVariant = Color(hex: 0x292e42)
}

// Rendered by matugen from templates/barpop.json.
@MainActor
@Observable
final class Palette {
	nonisolated static let path = NSString(string: "~/.local/state/matugen/barpop.json").expandingTildeInPath

	private(set) var roles = Roles()

	@ObservationIgnored private var source: DispatchSourceFileSystemObject?

	init() {
		load()
		watch()
	}

	private func load() {
		guard let data = FileManager.default.contents(atPath: Palette.path),
			let map = try? JSONSerialization.jsonObject(with: data) as? [String: String]
		else { return }
		var r = roles
		func set(_ key: String, _ role: WritableKeyPath<Roles, Color>) {
			if let c = map[key].flatMap(Color.init(hexString:)) { r[keyPath: role] = c }
		}
		set("surface", \.surface)
		set("surface_container", \.surfaceContainer)
		set("surface_container_high", \.surfaceContainerHigh)
		set("surface_container_highest", \.surfaceContainerHighest)
		set("on_surface", \.onSurface)
		set("on_surface_variant", \.onSurfaceVariant)
		set("primary", \.primary)
		set("on_primary", \.onPrimary)
		set("primary_container", \.primaryContainer)
		set("on_primary_container", \.onPrimaryContainer)
		set("secondary", \.secondary)
		set("tertiary", \.tertiary)
		set("error", \.error)
		set("outline_variant", \.outlineVariant)
		withAnimation(Motion.palette) { roles = r }
	}

	// matugen replaces the file, so the watch is re-armed on the new inode.
	// Until the file exists, its directory is watched for it to appear.
	private func watch() {
		source?.cancel()
		source = nil
		var fd = open(Palette.path, O_EVTONLY)
		let missing = fd < 0
		if missing { fd = open((Palette.path as NSString).deletingLastPathComponent, O_EVTONLY) }
		guard fd >= 0 else { return }
		let src = DispatchSource.makeFileSystemObjectSource(
			fileDescriptor: fd, eventMask: missing ? .write : [.write, .extend, .attrib, .delete, .rename], queue: .main)
		src.setEventHandler { [weak self] in
			MainActor.assumeIsolated {
				guard let self else { return }
				if missing || !src.data.isDisjoint(with: [.delete, .rename]) { self.watch() }
				self.load()
			}
		}
		src.setCancelHandler { close(fd) }
		src.resume()
		source = src
	}
}

extension Color {
	init(hex: UInt32) {
		self.init(
			red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255,
			blue: Double(hex & 0xff) / 255)
	}

	init?(hexString: String) {
		let s = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
		guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
		self.init(hex: v)
	}
}
