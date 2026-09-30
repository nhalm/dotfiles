import Charts
import SwiftUI

// A changing number with its label, on a raised tile.
struct StatTile<Accessory: View>: View {
	@Environment(\.theme) private var theme
	let label: String
	var symbol: String?
	let value: String
	var unit: String?
	var detail: String?
	@ViewBuilder var accessory: Accessory

	var body: some View {
		VStack(alignment: .leading, spacing: Space.s1) {
			HStack(spacing: Space.s1) {
				if let symbol { Image(systemName: symbol) }
				Text(label).lineLimit(1)
				Spacer(minLength: 0)
				accessory
			}
			.font(Theme.Font.caption)
			.foregroundStyle(theme.textSecondary)
			HStack(alignment: .firstTextBaseline, spacing: 2) {
				Text(value).font(Theme.Font.headline).contentTransition(.numericText())
				if let unit { Text(unit).font(Theme.Font.caption).foregroundStyle(theme.textSecondary) }
			}
			.animation(Motion.numeric, value: value)
			.padding(.top, 2)
			if let detail {
				Text(detail).font(Theme.Font.caption).foregroundStyle(theme.textSecondary).lineLimit(1)
			}
		}
		.padding(Space.s3)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(theme.raised, in: .rect(cornerRadius: Radius.tile, style: .continuous))
	}
}

extension StatTile where Accessory == EmptyView {
	init(label: String, symbol: String? = nil, value: String, unit: String? = nil, detail: String? = nil) {
		self.init(label: label, symbol: symbol, value: value, unit: unit, detail: detail, accessory: { EmptyView() })
	}
}

// Equal-width tiles in rows of `columns`.
struct StatGrid<Content: View>: View {
	let columns: Int
	@ViewBuilder let content: Content

	var body: some View {
		Group(subviews: content) { tiles in
			VStack(spacing: Space.s2) {
				ForEach(Array(stride(from: 0, to: tiles.count, by: columns)), id: \.self) { start in
					HStack(spacing: Space.s2) {
						ForEach(tiles[start..<min(start + columns, tiles.count)]) { $0 }
					}
					.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
	}
}

// Points the way something travels, e.g. wind from `degrees` blows toward
// the arrow.
struct Compass: View {
	@Environment(\.theme) private var theme
	let degrees: Double

	var body: some View {
		Image(systemName: "arrow.down")
			.font(Theme.Font.caption)
			.foregroundStyle(theme.textSecondary)
			.rotationEffect(.degrees(degrees))
	}
}

// A span of values over time: line and area, optional bars along the
// bottom (0…100), the first point marked as now. The first, last, highest
// and lowest points are labelled.
struct TrendChart: View {
	@Environment(\.theme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	let values: [Double]
	var bars: [Double]?
	let xLabels: [Int: String]
	let format: (Double) -> String

	var body: some View {
		let lo = values.min() ?? 0
		let hi = values.max() ?? 1
		let pad = max(hi - lo, 4) * 0.25
		let floor = lo - pad * 2
		let labeled = Set([0, values.count - 1, values.firstIndex(of: hi) ?? 0, values.firstIndex(of: lo) ?? 0])
		let last = values.count - 1
		Chart {
			if let bars {
				ForEach(Array(bars.enumerated()), id: \.offset) { i, v in
					BarMark(x: .value("Hour", i), yStart: .value("Base", floor), yEnd: .value("Chance", floor + v / 100 * pad * 2), width: 6)
						.foregroundStyle(theme.accent.opacity(0.35))
						.clipShape(.rect(cornerRadius: 2))
				}
			}
			ForEach(Array(values.enumerated()), id: \.offset) { i, v in
				AreaMark(x: .value("Hour", i), yStart: .value("Base", floor), yEnd: .value("Value", v))
					.interpolationMethod(.catmullRom)
					.foregroundStyle(
						LinearGradient(colors: [theme.accent.opacity(0.24), theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
				LineMark(x: .value("Hour", i), y: .value("Value", v))
					.interpolationMethod(.catmullRom)
					.foregroundStyle(theme.accent)
					.lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round))
				if labeled.contains(i) {
					PointMark(x: .value("Hour", i), y: .value("Value", v))
						.symbolSize(i == 0 ? 30 : 0)
						.foregroundStyle(theme.accent)
						.annotation(position: .top, alignment: i == 0 ? .leading : (i == last ? .trailing : .center), spacing: 4) {
							Text(format(v)).font(Theme.Font.caption).foregroundStyle(theme.textSecondary)
						}
				}
			}
			RuleMark(y: .value("Base", floor)).foregroundStyle(theme.hairline).lineStyle(StrokeStyle(lineWidth: 1))
		}
		.chartYScale(domain: floor...(hi + pad))
		.chartXScale(domain: 0...max(last, 1))
		.chartYAxis(.hidden)
		.chartXAxis {
			AxisMarks(values: xLabels.keys.sorted()) { mark in
				let i = mark.as(Int.self) ?? 0
				AxisValueLabel(anchor: i == 0 ? .topLeading : (i == last ? .topTrailing : .top)) {
					Text(xLabels[i] ?? "").font(Theme.Font.caption).foregroundStyle(theme.textSecondary)
				}
			}
		}
		.chartOverlay { proxy in
			GeometryReader { geo in
				if !reduceMotion, let plot = proxy.plotFrame, let first = values.first,
					let p = proxy.position(for: (x: 0, y: first))
				{
					NowHalo(color: theme.accent).position(x: geo[plot].minX + p.x, y: geo[plot].minY + p.y)
				}
			}
		}
		.frame(height: 110)
	}
}

private struct NowHalo: View {
	let color: Color

	var body: some View {
		PhaseAnimator([false, true]) { on in
			Circle()
				.fill(color)
				.frame(width: 6, height: 6)
				.scaleEffect(on ? 3 : 1)
				.opacity(on ? 0 : 0.45)
		} animation: { on in
			on ? .easeOut(duration: 1.6) : nil
		}
		.allowsHitTesting(false)
	}
}

// Progress through a span of time as an arc from start to end, e.g. the
// sun's path through the day. nil draws only the track.
struct ArcProgress: View {
	@Environment(\.theme) private var theme
	let progress: Double?
	let start: (symbol: String, label: String)
	let end: (symbol: String, label: String)

	var body: some View {
		VStack(spacing: Space.s2) {
			GeometryReader { geo in
				let w = geo.size.width
				let h = geo.size.height
				let arc = Path(ellipseIn: CGRect(x: 8, y: 4, width: w - 16, height: (h - 4) * 2)).trimmedPath(from: 0.5, to: 1)
				ZStack {
					arc.stroke(theme.textSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.25, dash: [2, 4]))
					if let progress {
						let done = arc.trimmedPath(from: 0, to: min(max(progress, 0), 1))
						done.stroke(theme.accent, style: StrokeStyle(lineWidth: 1.75, lineCap: .round))
						if let dot = done.currentPoint {
							Circle().fill(theme.accentAlt).frame(width: 7, height: 7).position(dot)
						}
					}
					Rectangle().fill(theme.hairline).frame(height: 1).position(x: w / 2, y: h)
				}
			}
			.frame(height: 48)
			HStack {
				Label(start.label, systemImage: start.symbol)
				Spacer()
				Label(end.label, systemImage: end.symbol).labelStyle(TrailingIcon())
			}
			.font(Theme.Font.body)
			.monospacedDigit()
		}
	}
}

private struct TrailingIcon: LabelStyle {
	func makeBody(configuration: Configuration) -> some View {
		HStack(spacing: 6) {
			configuration.title
			configuration.icon
		}
	}
}

// Where a range sits within wider bounds, e.g. a day's low to high within
// the week's; the marker is now.
struct Meter: View {
	@Environment(\.theme) private var theme
	let range: ClosedRange<Double>
	let bounds: ClosedRange<Double>
	var marker: Double?
	let lowLabel: String
	let highLabel: String

	init(range: ClosedRange<Double>, in bounds: ClosedRange<Double>, marker: Double? = nil, labels: (String, String)) {
		self.range = range
		self.bounds = bounds
		self.marker = marker
		lowLabel = labels.0
		highLabel = labels.1
	}

	var body: some View {
		HStack(spacing: Space.s2) {
			Text(lowLabel).foregroundStyle(theme.textSecondary).frame(width: 32, alignment: .trailing)
			GeometryReader { geo in
				let span = max(bounds.upperBound - bounds.lowerBound, 1)
				let x = { (v: Double) in CGFloat((v - bounds.lowerBound) / span) * geo.size.width }
				ZStack(alignment: .leading) {
					Capsule().fill(theme.raised)
					Capsule()
						.fill(LinearGradient(colors: [theme.accentAlt, theme.accent], startPoint: .leading, endPoint: .trailing))
						.frame(width: max(x(range.upperBound) - x(range.lowerBound), 4))
						.offset(x: x(range.lowerBound))
					if let marker {
						Circle()
							.fill(theme.text)
							.frame(width: 8, height: 8)
							.overlay(Circle().strokeBorder(theme.card, lineWidth: 1.5).padding(-1.5))
							.offset(x: min(max(x(marker), 0), geo.size.width) - 4)
					}
				}
				.frame(height: 4)
				.frame(maxHeight: .infinity)
			}
			.frame(width: 110, height: 10)
			Text(highLabel).frame(width: 32, alignment: .trailing)
		}
		.monospacedDigit()
	}
}
