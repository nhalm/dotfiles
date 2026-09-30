import Foundation

// Runs tools from the bar's environment; launched from sketchybar or open(1),
// barpop's PATH may lack Homebrew and mise (matugen).
enum Shell {
	nonisolated static func output(_ args: String..., timeout: TimeInterval = 15) async -> String {
		await output(args, timeout: timeout)
	}

	nonisolated static func output(_ args: [String], timeout: TimeInterval = 15) async -> String {
		await withCheckedContinuation { cont in
			let p = process(args)
			let pipe = Pipe()
			p.standardOutput = pipe
			do { try p.run() } catch {
				cont.resume(returning: "")
				return
			}
			DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { p.terminate() } }
			// Read while it runs: a tool that fills the pipe blocks until it is drained.
			DispatchQueue.global().async {
				cont.resume(returning: String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
			}
		}
	}

	nonisolated static func spawn(_ args: String...) {
		try? process(args).run()
	}

	// Runs a long-lived tool, handing each line of its output to onLine in
	// order on a background queue, and calling onExit once it ends.
	nonisolated static func stream(
		_ args: [String], onLine: @escaping @Sendable (Data) -> Void, onExit: @escaping @Sendable () -> Void
	) -> Process? {
		let p = process(args)
		let pipe = Pipe()
		p.standardOutput = pipe
		let lines = LineBuffer()
		pipe.fileHandleForReading.readabilityHandler = { handle in
			let data = handle.availableData
			if data.isEmpty {
				handle.readabilityHandler = nil
				return
			}
			lines.append(data).forEach(onLine)
		}
		p.terminationHandler = { _ in onExit() }
		do { try p.run() } catch { return nil }
		return p
	}

	// Tells sketchybar about barpop's state, so bar items can style themselves.
	nonisolated static func trigger(_ event: String, _ env: [String: String]) {
		try? process(["sketchybar", "--trigger", event] + env.map { "\($0.key)=\($0.value)" }).run()
	}

	nonisolated static func process(_ args: [String]) -> Process {
		let p = Process()
		p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
		p.arguments = args
		var env = ProcessInfo.processInfo.environment
		env["PATH"] =
			NSString(string: "~/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:").expandingTildeInPath
			+ (env["PATH"] ?? "/usr/bin:/bin")
		p.environment = env
		p.standardError = FileHandle.nullDevice
		return p
	}
}

// Only touched from one pipe's serial readability handler.
private final class LineBuffer: @unchecked Sendable {
	private var pending = Data()

	func append(_ data: Data) -> [Data] {
		pending.append(data)
		var lines: [Data] = []
		while let end = pending.firstIndex(of: UInt8(ascii: "\n")) {
			lines.append(Data(pending[pending.startIndex..<end]))
			pending.removeSubrange(pending.startIndex...end)
		}
		return lines
	}
}
