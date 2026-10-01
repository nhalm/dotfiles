import Charts
import SwiftUI

// Recent values as a small line and area, oldest on the left, 0 at the
// bottom. `.alt` is for a second series beside the first. scale fixes the
// value at the top, e.g. 100 for a percentage; nil fits the values.
struct Sparkline: View {
	enum Tone { case accent, alt }

	@Environment(\.theme) private var theme
	let values: [Double]
	var tone = Tone.accent
	var scale: Double?
	var height: CGFloat = 28

	var body: some View {
		let color = tone == .accent ? theme.accent : theme.accentAlt
		let top = scale ?? max(values.max() ?? 0, 1) * 1.15
		Chart {
			ForEach(Array(values.enumerated()), id: \.offset) { i, v in
				AreaMark(x: .value("Time", i), yStart: .value("Base", 0), yEnd: .value("Value", v))
					.interpolationMethod(.monotone)
					.foregroundStyle(color.opacity(0.12))
				LineMark(x: .value("Time", i), y: .value("Value", v))
					.interpolationMethod(.monotone)
					.foregroundStyle(color)
					.lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
			}
		}
		.chartXScale(domain: 0...max(values.count - 1, 1))
		.chartYScale(domain: -top * 0.04...top)
		.chartXAxis(.hidden)
		.chartYAxis(.hidden)
		.chartLegend(.hidden)
		.frame(height: height)
	}
}
