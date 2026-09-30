import AppKit
import ImageIO
import Observation

struct Wallpaper: Identifiable, Sendable, Equatable {
	let path: String
	let modified: Date

	var id: String { path }
	var name: String { ((path as NSString).lastPathComponent as NSString).deletingPathExtension }
	var kind: String { (path as NSString).pathExtension.uppercased() }
	// Caches follow the file, so a replaced image is read again.
	var key: String { "\(path)|\(modified.timeIntervalSince1970)" }
}

// The wallpaper library (~/.local/share/wallpapers), applied with
// wallpaper.sh, which records the current one in the state file and renders
// every app's palette from it with matugen. Hovering one previews the dark
// palette matugen would derive, without writing anything.
@MainActor
@Observable
final class Wallpapers {
	enum Applying { case idle, running, done }

	struct Preview: Equatable {
		let name: String
		let swatches: [Swatch]
	}

	// WALLPAPER_DIR, else the XDG data home's.
	nonisolated static let folder: String = {
		let env = ProcessInfo.processInfo.environment
		if let dir = env["WALLPAPER_DIR"], !dir.isEmpty { return dir }
		return (env["XDG_DATA_HOME"] ?? NSString(string: "~/.local/share").expandingTildeInPath) + "/wallpapers"
	}()
	nonisolated static var displayFolder: String { (folder as NSString).abbreviatingWithTildeInPath }
	private nonisolated static let kinds: Set = ["jpg", "jpeg", "png", "heic", "webp"]
	private nonisolated static let roles = ["primary", "secondary", "tertiary", "surface"]
	private nonisolated static let script = NSString(string: "~/.local/scripts/wallpaper.sh").expandingTildeInPath
	private nonisolated static let config = NSString(string: "~/.config/matugen/config.toml").expandingTildeInPath
	private nonisolated static var stateFile: String {
		let base = ProcessInfo.processInfo.environment["XDG_STATE_HOME"] ?? NSString(string: "~/.local/state").expandingTildeInPath
		return base + "/wallpaper"
	}

	private(set) var all: [Wallpaper] = []
	private(set) var current: String?
	private(set) var highlighted: String?
	private(set) var thumbnails: [String: NSImage] = [:]
	private(set) var preview: Preview?
	private(set) var applying = Applying.idle
	var query = "" {
		didSet {
			guard let highlighted, !matches.contains(where: { $0.path == highlighted }) else { return }
			self.highlighted = nil
			showPreview()
		}
	}

	private var sizes: [String: CGSize] = [:]
	@ObservationIgnored private var palettes: [String: [Swatch]] = [:]
	@ObservationIgnored private var previewTask: Task<Void, Never>?
	@ObservationIgnored private var doneTask: Task<Void, Never>?

	var matches: [Wallpaper] {
		let q = query.lowercased().filter { !$0.isWhitespace }
		guard !q.isEmpty else { return all }
		return all.filter { Self.fuzzy($0.name.lowercased(), q) }
	}

	var currentWallpaper: Wallpaper? {
		guard let current else { return nil }
		return all.first { $0.path == current }
			?? Wallpaper(path: current, modified: .distantPast)
	}

	var currentDetail: String {
		guard let w = currentWallpaper else { return "None applied" }
		let size = sizes[w.key].map { "\(Int($0.width)) × \(Int($0.height))" }
		return (["Current", size, w.kind] as [String?]).compactMap { $0 }.joined(separator: " · ")
	}

	func open() {
		query = ""
		highlighted = nil
		scan()
		readCurrent()
		loadThumbnails()
		showPreview()
	}

	// From the pointer: leaving one clears the highlight only if it is still
	// that one, so crossing the gap to the next does not flash the current.
	func hover(_ w: Wallpaper, _ inside: Bool) {
		if inside {
			highlighted = w.path
		} else if highlighted == w.path {
			highlighted = nil
		}
		showPreview()
	}

	func move(by step: Int) {
		let list = matches
		guard !list.isEmpty else { return }
		let at = list.firstIndex { $0.path == highlighted }
		let next = at.map { min(max($0 + step, 0), list.count - 1) } ?? 0
		highlighted = list[next].path
		showPreview()
	}

	// Return applies the highlighted match, or the first.
	func submit() {
		let list = matches
		guard let w = list.first(where: { $0.path == highlighted }) ?? list.first else { return }
		apply(w)
	}

	func apply(_ w: Wallpaper) {
		guard applying != .running else { return }
		doneTask?.cancel()
		applying = .running
		current = w.path
		Task {
			_ = await Shell.output([Self.script, w.path], timeout: 60)
			readCurrent()
			finish()
		}
	}

	// Palette's file watch has picked up the new colours.
	func paletteChanged() {
		if applying == .running { finish() }
	}

	func openFolder() { NSWorkspace.shared.open(URL(fileURLWithPath: Self.folder)) }

	private func finish() {
		guard applying == .running else { return }
		applying = .done
		doneTask = Task {
			try? await Task.sleep(for: .seconds(1.5))
			if !Task.isCancelled { applying = .idle }
		}
	}

	private func scan() {
		let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey]
		let urls =
			(try? FileManager.default.contentsOfDirectory(
				at: URL(fileURLWithPath: Self.folder), includingPropertiesForKeys: keys, options: .skipsHiddenFiles)) ?? []
		all = urls.compactMap { url in
			let file = url.resolvingSymlinksInPath()
			guard Self.kinds.contains(file.pathExtension.lowercased()),
				let v = try? file.resourceValues(forKeys: Set(keys)), v.isRegularFile == true
			else { return nil }
			return Wallpaper(path: url.path, modified: v.contentModificationDate ?? .distantPast)
		}
		// As sort(1) orders them in the user's locale.
		.sorted { $0.path.localizedCompare($1.path) == .orderedAscending }
	}

	private func readCurrent() {
		current = (try? String(contentsOfFile: Self.stateFile, encoding: .utf8))
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.flatMap { $0.isEmpty ? nil : $0 }
	}

	// Four at a time: a large PNG decodes whole before it is scaled.
	private func loadThumbnails() {
		let missing = all.filter { thumbnails[$0.key] == nil }
		guard !missing.isEmpty else { return }
		Task {
			await withTaskGroup(of: (String, CGImage?, CGSize?).self) { group in
				var queue = missing[...]
				func next() {
					guard let w = queue.popFirst() else { return }
					group.addTask { Self.thumbnail(w) }
				}
				for _ in 0..<4 { next() }
				for await (key, image, size) in group {
					if let image { thumbnails[key] = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)) }
					if let size { sizes[key] = size }
					next()
				}
			}
		}
	}

	private nonisolated static func thumbnail(_ w: Wallpaper) -> (String, CGImage?, CGSize?) {
		guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: w.path) as CFURL, nil) else { return (w.key, nil, nil) }
		let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
		let size = (props?[kCGImagePropertyPixelWidth] as? Int).flatMap { width in
			(props?[kCGImagePropertyPixelHeight] as? Int).map { CGSize(width: width, height: $0) }
		}
		let image = CGImageSourceCreateThumbnailAtIndex(
			src, 0,
			[
				kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 400,
				kCGImageSourceCreateThumbnailWithTransform: true,
			] as CFDictionary)
		return (w.key, image, size)
	}

	// The highlighted one's palette, else the current one's. Cached ones show
	// at once; others wait out a short hover first, and the last palette
	// stays up until the new one is ready.
	private func showPreview() {
		previewTask?.cancel()
		guard let w = all.first(where: { $0.path == highlighted }) ?? currentWallpaper else { return }
		if let swatches = palettes[w.key] {
			preview = Preview(name: w.name, swatches: swatches)
			return
		}
		previewTask = Task {
			try? await Task.sleep(for: .milliseconds(80))
			guard !Task.isCancelled else { return }
			let swatches = await Self.swatches(w.path)
			guard !swatches.isEmpty else { return }
			palettes[w.key] = swatches
			if !Task.isCancelled { preview = Preview(name: w.name, swatches: swatches) }
		}
	}

	// wallpaper.sh's matugen call, dry, in the dark scheme barpop draws with.
	private nonisolated static func swatches(_ path: String) async -> [Swatch] {
		let out = await Shell.output([
			"matugen", "-c", config, "image", path, "-m", "dark", "--source-color-index", "0", "--dry-run", "--json", "hex",
		])
		guard let json = try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any],
			let colors = json["colors"] as? [String: [String: [String: String]]]
		else { return [] }
		return roles.compactMap { role in colors[role]?["dark"]?["color"].map { Swatch(role: role, hex: $0) } }
	}

	private nonisolated static func fuzzy(_ name: String, _ query: String) -> Bool {
		var rest = name[...]
		for c in query {
			guard let i = rest.firstIndex(of: c) else { return false }
			rest = rest[rest.index(after: i)...]
		}
		return true
	}
}
