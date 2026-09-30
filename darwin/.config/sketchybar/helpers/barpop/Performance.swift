import AppKit
import Darwin
import Observation

struct CPULoad: Sendable {
	var user = 0.0
	var system = 0.0

	var total: Double { user + system }
}

struct MemoryUse: Sendable {
	enum Pressure: Sendable { case normal, warning, critical }

	let total: UInt64
	let used: UInt64
	let compressed: UInt64
	let swap: UInt64
	let pressure: Pressure?
}

struct TopProcess: Identifiable {
	let id: pid_t
	let name: String
	let cpu: Double
	let memory: UInt64
	let icon: NSImage?
	let isApp: Bool
}

// CPU and memory every 5s in the background, for two minutes of history;
// while the popup is open, per-core load and the top processes as well.
@MainActor
@Observable
final class Performance {
	enum Sort { case cpu, memory }

	static let history = 24

	private(set) var load = CPULoad()
	private(set) var history: [Double] = []
	private(set) var cores: [Double] = []
	private(set) var loadAverage: [Double] = []
	private(set) var memory: MemoryUse?
	private(set) var processes: [TopProcess] = []
	private(set) var sort = Sort.cpu
	private(set) var thermal = ProcessInfo.processInfo.thermalState
	private(set) var disk: (free: Int64, total: Int64)?
	private(set) var uptime: TimeInterval?
	// Apple silicon numbers its efficiency cores first.
	let efficiencyCores = Performance.sysctlInt("hw.nperflevels") == 2 ? Performance.sysctlInt("hw.perflevel1.logicalcpu") ?? 0 : 0

	@ObservationIgnored private let sampler = Sampler()
	@ObservationIgnored private var monitors = 0
	@ObservationIgnored private let boot = Performance.bootTime()

	init() {
		NotificationCenter.default.addObserver(
			forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil
		) { [weak self] _ in
			Task { @MainActor in self?.thermal = ProcessInfo.processInfo.thermalState }
		}
		Task {
			while true {
				let (cpu, mem) = await sampler.background()
				if let cpu {
					history = Array((history + [cpu.total]).suffix(Self.history))
					if monitors == 0 { load = cpu }
				}
				memory = mem
				try? await Task.sleep(for: .seconds(5))
			}
		}
	}

	func monitor() async {
		monitors += 1
		defer { monitors -= 1 }
		thermal = ProcessInfo.processInfo.thermalState
		Task { disk = await Task.detached { Self.diskSpace() }.value }
		await sampler.resetCores()
		try? await Task.sleep(for: .milliseconds(250))
		while !Task.isCancelled {
			async let top = Self.top(sort)
			let s = await sampler.live()
			load = s.load
			cores = s.cores
			loadAverage = s.loadAverage
			memory = s.memory
			uptime = boot.map { Date().timeIntervalSince($0) }
			publish(await top)
			try? await Task.sleep(for: .seconds(1.5))
		}
	}

	func setSort(_ sort: Sort) {
		guard sort != self.sort else { return }
		self.sort = sort
		Task { publish(await Self.top(sort)) }
	}

	func activate(_ process: TopProcess) {
		NSRunningApplication(processIdentifier: process.id)?.activate()
	}

	static func openActivityMonitor() {
		guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") else { return }
		NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
	}

	private struct Row: Sendable {
		let pid: pid_t
		let cpu: Double
		let rss: UInt64
		let comm: String
	}

	// A list for a sort the user has since changed is dropped.
	private func publish(_ top: (sort: Sort, rows: [Row])) {
		guard top.sort == sort else { return }
		processes = top.rows.map { r in
			let app = NSRunningApplication(processIdentifier: r.pid).flatMap { $0.activationPolicy == .regular ? $0 : nil }
			return TopProcess(
				id: r.pid, name: app?.localizedName ?? r.comm, cpu: r.cpu, memory: r.rss, icon: app?.icon, isApp: app != nil)
		}
	}

	private nonisolated static func top(_ sort: Sort) async -> (sort: Sort, rows: [Row]) {
		let out = await Shell.output("ps", "-Aceo", "pid=,pcpu=,rss=,comm=", sort == .cpu ? "-r" : "-m")
		let rows = out.split(separator: "\n").lazy.compactMap { line -> Row? in
			let cols = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
			guard cols.count == 4, let pid = pid_t(cols[0]), let cpu = Double(cols[1]), let rss = UInt64(cols[2]) else {
				return nil
			}
			return Row(pid: pid, cpu: cpu, rss: rss * 1024, comm: String(cols[3]))
		}
		return (sort, Array(rows.prefix(5)))
	}

	private nonisolated static func diskSpace() -> (free: Int64, total: Int64)? {
		let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [
			.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey,
		])
		guard let free = v?.volumeAvailableCapacityForImportantUsage, let total = v?.volumeTotalCapacity else { return nil }
		return (free, Int64(total))
	}

	private nonisolated static func bootTime() -> Date? {
		var tv = timeval()
		var size = MemoryLayout<timeval>.size
		guard sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 else { return nil }
		return Date(timeIntervalSince1970: TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000)
	}

	nonisolated static func sysctlInt(_ name: String) -> Int? {
		var v: Int32 = 0
		var size = MemoryLayout<Int32>.size
		return sysctlbyname(name, &v, &size, nil, 0) == 0 ? Int(v) : nil
	}
}

// Keeps the tick counts the load is measured against, off the main actor.
// One host port for the app's life, so each sample adds no send right.
private actor Sampler {
	struct Live: Sendable {
		let load: CPULoad
		let cores: [Double]
		let loadAverage: [Double]
		let memory: MemoryUse?
	}

	private let host = mach_host_self()
	private let pageSize = UInt64(sysconf(_SC_PAGESIZE))
	private let memsize: UInt64 = {
		var v: UInt64 = 0
		var size = MemoryLayout<UInt64>.size
		return sysctlbyname("hw.memsize", &v, &size, nil, 0) == 0 ? v : 0
	}()
	private var totalTicks: [UInt32]?
	private var coreTicks: [[UInt32]] = []

	// The first call only sets the baseline.
	func background() -> (CPULoad?, MemoryUse?) {
		var info = host_cpu_load_info()
		var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
		let kr = withUnsafeMutablePointer(to: &info) {
			$0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
		}
		var load: CPULoad?
		if kr == KERN_SUCCESS {
			let t = info.cpu_ticks
			let now = [t.0, t.1, t.2, t.3]
			if let prev = totalTicks { load = Self.load(prev, now) }
			totalTicks = now
		}
		return (load, memory())
	}

	func resetCores() { coreTicks = perCoreTicks() ?? [] }

	func live() -> Live {
		let now = perCoreTicks() ?? []
		let prev = coreTicks.count == now.count ? coreTicks : now
		coreTicks = now
		let loads = zip(prev, now).map { Self.load($0, $1) }
		let n = Double(max(loads.count, 1))
		let load = CPULoad(user: loads.map(\.user).reduce(0, +) / n, system: loads.map(\.system).reduce(0, +) / n)
		var avg = [0.0, 0.0, 0.0]
		let got = getloadavg(&avg, 3)
		return Live(
			load: load, cores: loads.map { $0.total / 100 }, loadAverage: got == 3 ? avg : [], memory: memory())
	}

	// Ticks in CPU_STATE order: user, system, idle, nice. They wrap.
	private static func load(_ a: [UInt32], _ b: [UInt32]) -> CPULoad {
		let d = zip(a, b).map { Double($1 &- $0) }
		let sum = d.reduce(0, +)
		guard sum > 0 else { return CPULoad() }
		return CPULoad(
			user: (d[Int(CPU_STATE_USER)] + d[Int(CPU_STATE_NICE)]) / sum * 100, system: d[Int(CPU_STATE_SYSTEM)] / sum * 100)
	}

	private func perCoreTicks() -> [[UInt32]]? {
		var cpus: natural_t = 0
		var info: processor_info_array_t?
		var count: mach_msg_type_number_t = 0
		guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpus, &info, &count) == KERN_SUCCESS, let info else {
			return nil
		}
		defer {
			vm_deallocate(
				mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(count) * vm_size_t(MemoryLayout<integer_t>.stride))
		}
		let states = Int(CPU_STATE_MAX)
		return (0..<Int(cpus)).map { cpu in (0..<states).map { UInt32(bitPattern: info[cpu * states + $0]) } }
	}

	// Used as Activity Monitor counts it: app memory, wired and compressed.
	private func memory() -> MemoryUse? {
		var vm = vm_statistics64()
		var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
		let kr = withUnsafeMutablePointer(to: &vm) {
			$0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
		}
		guard kr == KERN_SUCCESS else { return nil }
		let app = UInt64(vm.internal_page_count) - min(UInt64(vm.purgeable_count), UInt64(vm.internal_page_count))
		let compressed = UInt64(vm.compressor_page_count) * pageSize
		var swap = xsw_usage()
		var size = MemoryLayout<xsw_usage>.size
		let swapUsed = sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 ? swap.xsu_used : 0
		let pressure: MemoryUse.Pressure? =
			switch Performance.sysctlInt("kern.memorystatus_vm_pressure_level") {
			case 1: .normal
			case 2: .warning
			case 4: .critical
			default: nil
			}
		return MemoryUse(
			total: memsize, used: min((app + UInt64(vm.wire_count)) * pageSize + compressed, memsize),
			compressed: compressed, swap: swapUsed, pressure: pressure)
	}
}
