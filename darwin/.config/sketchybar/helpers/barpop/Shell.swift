import Foundation

// Runs tools from the bar's environment; launched from sketchybar or open(1),
// barpop's PATH may lack Homebrew.
enum Shell {
	nonisolated static func output(_ args: String..., timeout: TimeInterval = 15) async -> String {
		await output(args, timeout: timeout)
	}

	nonisolated static func output(_ args: [String], timeout: TimeInterval = 15) async -> String {
		await withCheckedContinuation { cont in
			let p = process(args)
			let pipe = Pipe()
			p.standardOutput = pipe
			p.terminationHandler = { _ in
				cont.resume(returning: String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
			}
			do { try p.run() } catch {
				cont.resume(returning: "")
				return
			}
			DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { p.terminate() } }
		}
	}

	nonisolated static func spawn(_ args: String...) {
		try? process(args).run()
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
		env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
		p.environment = env
		p.standardError = FileHandle.nullDevice
		return p
	}
}
