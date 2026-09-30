import SwiftUI

// An analogue clock for a tile accessory: a light dial by day, a dark one
// from 18:00 to 06:00 in timeZone.
struct ClockFace: View {
	@Environment(\.theme) private var theme
	let date: Date
	let timeZone: TimeZone

	var body: some View {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = timeZone
		let t = c.dateComponents([.hour, .minute], from: date)
		let hour = Double(t.hour ?? 0)
		let minute = Double(t.minute ?? 0)
		let night = hour >= 18 || hour < 6
		let hands = night ? theme.text : theme.card
		return Canvas { ctx, size in
			let r = size.width / 2
			let center = CGPoint(x: r, y: r)
			let dial = Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1))
			ctx.fill(dial, with: .color(night ? theme.deep : theme.text))
			if night { ctx.stroke(dial, with: .color(theme.hairline), lineWidth: 1) }
			let spec: [(turns: Double, length: CGFloat, width: CGFloat)] = [
				((hour.truncatingRemainder(dividingBy: 12) + minute / 60) / 12, r * 0.45, 2),
				(minute / 60, r * 0.72, 1.4),
			]
			for h in spec {
				let a = h.turns * 2 * .pi
				var hand = Path()
				hand.move(to: center)
				hand.addLine(to: CGPoint(x: center.x + sin(a) * h.length, y: center.y - cos(a) * h.length))
				ctx.stroke(hand, with: .color(hands), style: StrokeStyle(lineWidth: h.width, lineCap: .round))
			}
			ctx.fill(Path(ellipseIn: CGRect(x: r - 1.3, y: r - 1.3, width: 2.6, height: 2.6)), with: .color(theme.accent))
		}
		.frame(width: 28, height: 28)
		// Sits into the tile's corner rather than pushing its first line down.
		.padding(.vertical, -Space.s1)
		.padding(.trailing, -Space.s2)
		.accessibilityHidden(true)
	}
}
