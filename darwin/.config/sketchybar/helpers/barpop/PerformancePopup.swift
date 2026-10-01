import SwiftUI

struct PerformancePopup: View {
	@Environment(Performance.self) private var perf
	@Environment(Presentation.self) private var presentation

	var body: some View {
		PopupCard(width: .wide) {
			HeroHeader(eyebrow: "CPU", eyebrowSymbol: "cpu", value: "\(Int(perf.load.total.rounded()))", unit: "%", subtitle: subtitle, live: true)
			Section("Last 2 minutes", trailing: perf.history.max().map { "Peak \(Int($0.rounded()))%" }) {
				Sparkline(values: perf.history, scale: 100, height: 44)
			}
			if !perf.cores.isEmpty { BarStrip(coreGroups) }
			Section("System") {
				StatGrid(columns: 3) {
					if let memory = perf.memory {
						let used = bytes(memory.used)
						StatTile(label: "Memory", value: used.value, unit: used.unit, detail: "of \(bytes(memory.total).joined)", live: true)
						let compressed = bytes(memory.compressed)
						StatTile(label: "Compressed", value: compressed.value, unit: compressed.unit, live: true)
						let swap = bytes(memory.swap)
						StatTile(label: "Swap", value: swap.value, unit: swap.unit, live: true)
					}
					StatTile(label: "Thermal", value: thermal)
					if let disk = perf.disk {
						let free = storage(disk.free)
						StatTile(label: "Disk free", value: free.value, unit: free.unit, detail: "of \(storage(disk.total).joined)")
					}
					if let uptime = perf.uptime { StatTile(label: "Uptime", value: duration(uptime)) }
				}
			} trailing: {
				switch perf.memory?.pressure {
				case .critical: Chip("Memory pressure critical", tone: .critical)
				case .warning: Text("Memory pressure elevated")
				case .normal: Text("Memory pressure normal")
				case nil: EmptyView()
				}
			}
			if !perf.processes.isEmpty {
				Section("Top processes") {
					ForEach(perf.processes) { p in
						ListItem(
							title: p.name, subtitle: perf.sort == .cpu ? bytes(p.memory).joined : percent(p.cpu),
							symbol: "gearshape", icon: p.icon,
							value: perf.sort == .cpu ? percent(p.cpu) : bytes(p.memory).joined,
							action: p.isApp
								? {
									perf.activate(p)
									presentation.close()
								} : nil)
					}
				} trailing: {
					SegmentedToggle(
						[("CPU", Performance.Sort.cpu), ("Memory", .memory)],
						selection: Binding(get: { perf.sort }, set: { perf.setSort($0) }))
				}
			}
			FooterLink("Open Activity Monitor") { Performance.openActivityMonitor() }
		}
		.whileOpen { await perf.monitor() }
	}

	private var subtitle: String {
		var parts = ["User \(Int(perf.load.user.rounded()))%", "System \(Int(perf.load.system.rounded()))%"]
		if !perf.loadAverage.isEmpty {
			parts.append("Load " + perf.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " "))
		}
		return parts.joined(separator: " · ")
	}

	private var coreGroups: [BarGroup] {
		let e = perf.efficiencyCores
		guard e > 0, e < perf.cores.count else { return [BarGroup(label: "\(perf.cores.count) cores", values: perf.cores)] }
		return [
			BarGroup(label: "Efficiency cores", values: Array(perf.cores.prefix(e))),
			BarGroup(label: "Performance cores", values: Array(perf.cores.dropFirst(e))),
		]
	}

	private var thermal: String {
		switch perf.thermal {
		case .nominal: "Normal"
		case .fair: "Fair"
		case .serious: "Serious"
		case .critical: "Critical"
		@unknown default: "Unknown"
		}
	}

	private func percent(_ v: Double) -> String { "\(Int(v.rounded()))%" }

	private func bytes(_ n: UInt64) -> (value: String, unit: String, joined: String) {
		let gb = Double(n) / 1_073_741_824
		let (value, unit) =
			gb >= 100 ? ("\(Int(gb.rounded()))", "GB")
			: gb >= 1 ? (String(format: "%.1f", gb), "GB") : ("\(Int((gb * 1024).rounded()))", "MB")
		return (value, unit, "\(value) \(unit)")
	}

	// Decimal, as Finder counts disk space.
	private func storage(_ n: Int64) -> (value: String, unit: String, joined: String) {
		let gb = Double(max(n, 0)) / 1_000_000_000
		let value = gb >= 10 ? "\(Int(gb.rounded()))" : String(format: "%.1f", gb)
		return (value, "GB", "\(value) GB")
	}

	private func duration(_ t: TimeInterval) -> String {
		let f = DateComponentsFormatter()
		f.allowedUnits = t >= 86_400 ? [.day, .hour] : [.hour, .minute]
		f.unitsStyle = .abbreviated
		f.maximumUnitCount = 2
		return f.string(from: t) ?? ""
	}
}
