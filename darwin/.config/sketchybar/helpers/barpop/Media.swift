import AppKit
import Observation

struct NowPlaying: Sendable, Equatable {
	let bundleID: String?
	let pid: pid_t?
	let title: String
	let artist: String?
	let album: String?
	let artwork: Data?
	let duration: TimeInterval?
	let elapsed: TimeInterval
	let timestamp: Date
	let rate: Double
	let isPlaying: Bool

	// Safari plays through a WebKit helper that names Safari as its parent.
	init?(_ d: [String: Any]) {
		guard let title = d["title"] as? String, !title.isEmpty else { return nil }
		let micros = { (key: String) in (d[key] as? Double).map { $0 / 1_000_000 } }
		self.title = title
		bundleID = d["parentApplicationBundleIdentifier"] as? String ?? d["bundleIdentifier"] as? String
		pid = (d["processIdentifier"] as? Int).map(pid_t.init)
		artist = (d["artist"] as? String).flatMap { $0.isEmpty ? nil : $0 }
		album = (d["album"] as? String).flatMap { $0.isEmpty ? nil : $0 }
		artwork = (d["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
		duration = micros("durationMicros").flatMap { $0 > 0 ? $0 : nil }
		elapsed = micros("elapsedTimeMicros") ?? 0
		timestamp = micros("timestampEpochMicros").map { Date(timeIntervalSince1970: $0) } ?? Date()
		isPlaying = d["playing"] as? Bool ?? false
		rate = d["playbackRate"] as? Double ?? 1
	}

	var byline: String? {
		let s = [artist, album].compactMap { $0 }.joined(separator: " · ")
		return s.isEmpty ? nil : s
	}

	func elapsed(at date: Date) -> TimeInterval {
		let t = elapsed + (isPlaying ? date.timeIntervalSince(timestamp) * rate : 0)
		return min(max(t, 0), duration ?? .infinity)
	}
}

// What macOS reports as now playing, from a long-lived `media-control
// stream` (MediaRemote is closed to other callers since macOS 15.4).
// Browsers publish their tabs' media here too. The bar's chip follows it
// through the barpop_media event.
@MainActor
@Observable
final class Media {
	struct Source {
		let name: String
		let icon: NSImage?
		let url: URL?
	}

	private(set) var now: NowPlaying?
	private(set) var artwork: NSImage?
	private(set) var source: Source?

	@ObservationIgnored private var process: Process?

	init() { start() }

	func togglePlayPause() { Shell.spawn("media-control", "toggle-play-pause") }
	func next() { Shell.spawn("media-control", "next-track") }
	func previous() { Shell.spawn("media-control", "previous-track") }
	func seek(_ seconds: TimeInterval) { Shell.spawn("media-control", "seek", String(format: "%.2f", seconds)) }

	func openSource() {
		guard let url = source?.url else { return }
		NSWorkspace.shared.openApplication(at: url, configuration: .init())
	}

	private func start() {
		let state = StreamState()
		process = Shell.stream(["media-control", "stream", "--micros"]) { [weak self] line in
			let now = state.apply(line)
			DispatchQueue.main.async { MainActor.assumeIsolated { self?.update(now) } }
		} onExit: { [weak self] in
			DispatchQueue.main.async { MainActor.assumeIsolated { self?.restart() } }
		}
		if process == nil { restart() }
	}

	// A missing or crashed media-control is retried without spinning.
	private func restart() {
		process = nil
		update(nil)
		DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
			MainActor.assumeIsolated { self?.start() }
		}
	}

	private func update(_ now: NowPlaying?) {
		guard now != self.now else { return }
		let old = self.now
		self.now = now
		if now?.artwork != old?.artwork { artwork = now?.artwork.flatMap(Self.thumbnail) }
		if now?.bundleID != old?.bundleID || now?.pid != old?.pid { source = now.flatMap(Self.source) }
		if now?.title != old?.title || now?.artist != old?.artist || now?.isPlaying != old?.isPlaying {
			Shell.trigger(
				"barpop_media",
				["TITLE": now?.title ?? "", "ARTIST": now?.artist ?? "", "PLAYING": now?.isPlaying == true ? "1" : "0"])
		}
	}

	private static func source(_ now: NowPlaying) -> Source? {
		if let id = now.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
			let name =
				NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName
				?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
			return Source(name: name, icon: NSWorkspace.shared.icon(forFile: url.path), url: url)
		}
		guard let pid = now.pid, let app = NSRunningApplication(processIdentifier: pid) else { return nil }
		return Source(name: app.localizedName ?? "Now Playing", icon: app.icon, url: app.bundleURL)
	}

	// Browsers hand over full-size video frames; the popup needs ~600px.
	private static func thumbnail(_ data: Data) -> NSImage? {
		guard let src = CGImageSourceCreateWithData(data as CFData, nil),
			let cg = CGImageSourceCreateThumbnailAtIndex(
				src, 0,
				[
					kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 600,
					kCGImageSourceCreateThumbnailWithTransform: true,
				] as CFDictionary)
		else { return nil }
		return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
	}
}

// The stream's first line and any "diff": false line replace the state;
// the rest carry only the keys that changed, null for removed ones. Only
// touched from the stream's serial reader.
private final class StreamState: @unchecked Sendable {
	private var fields: [String: Any] = [:]

	func apply(_ line: Data) -> NowPlaying? {
		if let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
			let payload = message["payload"] as? [String: Any]
		{
			if message["diff"] as? Bool != true { fields = [:] }
			for (key, value) in payload {
				fields[key] = value is NSNull ? nil : value
			}
		}
		return NowPlaying(fields)
	}
}
