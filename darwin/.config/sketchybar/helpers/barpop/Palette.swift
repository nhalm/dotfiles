import Observation
import SwiftUI

// Rendered by matugen from templates/barpop.json; the fallback matches the
// bar's static TokyoNight table.
@MainActor
@Observable
final class Palette {
	nonisolated static let path = NSString(string: "~/.local/state/matugen/barpop.json").expandingTildeInPath

	var surface = Color(hex: 0x1a1b26)
	var container = Color(hex: 0x1f2335)
	var containerHigh = Color(hex: 0x24283b)
	var onSurface = Color(hex: 0xc0caf5)
	var onSurfaceVariant = Color(hex: 0x565f89)
	var primary = Color(hex: 0x7aa2f7)
	var onPrimary = Color(hex: 0x1a1b26)
	var primaryContainer = Color(hex: 0x3d59a1)
	var tertiary = Color(hex: 0xbb9af7)
	var outline = Color(hex: 0x292e42)

	@ObservationIgnored private var source: DispatchSourceFileSystemObject?

	init() {
		load()
		watch()
	}

	private func load() {
		guard let data = FileManager.default.contents(atPath: Palette.path),
			let map = try? JSONSerialization.jsonObject(with: data) as? [String: String]
		else { return }
		func c(_ key: String) -> Color? { map[key].flatMap(Color.init(hexString:)) }
		surface = c("surface") ?? surface
		container = c("surface_container") ?? container
		containerHigh = c("surface_container_high") ?? containerHigh
		onSurface = c("on_surface") ?? onSurface
		onSurfaceVariant = c("on_surface_variant") ?? onSurfaceVariant
		primary = c("primary") ?? primary
		onPrimary = c("on_primary") ?? onPrimary
		primaryContainer = c("primary_container") ?? primaryContainer
		tertiary = c("tertiary") ?? tertiary
		outline = c("outline_variant") ?? outline
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
