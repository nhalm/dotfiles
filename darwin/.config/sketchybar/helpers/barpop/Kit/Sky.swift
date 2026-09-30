import SwiftUI

enum SkyCondition { case clear, partlyCloudy, cloudy, rain, snow, storm }

// An illustrated sky for HeroHeader's backdrop: gradient, sun or moon and
// stars, drifting clouds, rain or snow, and hills in the card's own colour so
// the sky settles into the card.
struct SkyScene: View {
	@Environment(\.theme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	let condition: SkyCondition
	let isNight: Bool

	var body: some View {
		TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
			let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
			Canvas { ctx, size in draw(&ctx, size, t) }
		}
		.background(LinearGradient(colors: gradient, startPoint: UnitPoint(x: 0.45, y: 0), endPoint: UnitPoint(x: 0.55, y: 1)))
		.clipped()
		.allowsHitTesting(false)
	}

	private var gradient: [Color] {
		let sky = theme.sky
		let base = isNight ? [sky.nightTop, sky.nightBottom] : [sky.dayTop, sky.dayBottom]
		let overcast: Double =
			switch condition {
			case .clear, .partlyCloudy: 0
			case .cloudy, .rain, .snow: isNight ? 0.15 : 0.35
			case .storm: isNight ? 0.3 : 0.55
			}
		return base.map { $0.mix(with: sky.cloudDark, by: overcast) }
	}

	private var clouds: [(x: CGFloat, y: CGFloat, w: CGFloat, phase: Double)] {
		switch condition {
		case .clear: []
		case .partlyCloudy: [(-124, 58, 70, 2), (-170, 84, 40, 5)]
		case .cloudy: [(-190, 40, 64, 1), (-128, 54, 84, 4), (-214, 80, 44, 6)]
		case .rain, .storm, .snow: [(-176, 36, 84, 1), (-96, 58, 64, 4)]
		}
	}

	private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
		let sky = theme.sky
		let w = size.width
		let h = size.height
		let dark = condition == .cloudy || condition == .storm

		if isNight && !dark {
			let stars: [(CGFloat, CGFloat, Double)] = [
				(0.08, 14, 0), (0.22, 30, 1.2), (0.36, 12, 0.5), (0.47, 36, 2), (0.58, 18, 0.8), (0.7, 8, 2.4), (0.92, 40, 1.6),
			]
			for (x, y, delay) in stars {
				let twinkle = 0.5 + 0.5 * sin(2 * .pi * (t + delay) / 3)
				ctx.fill(
					Path(ellipseIn: CGRect(x: x * w, y: y, width: 2, height: 2)),
					with: .color(theme.text.opacity(0.25 + 0.5 * twinkle)))
			}
		}

		if !isNight && (condition == .clear || condition == .partlyCloudy) {
			let c = CGPoint(x: w - 62, y: 46)
			let breathe = 1 + 0.06 * sin(2 * .pi * t / 5)
			for (ring, alpha) in [(CGFloat(22), 0.07), (10, 0.16)] {
				let r = (23 + ring) * breathe
				ctx.fill(circle(c, r), with: .color(sky.sun.opacity(alpha)))
			}
			ctx.fill(
				circle(c, 23),
				with: .radialGradient(
					Gradient(colors: [sky.sun.mix(with: Color.white, by: 0.3), sky.sun]),
					center: CGPoint(x: c.x - 6, y: c.y - 6), startRadius: 0, endRadius: 28))
		} else if isNight && !dark {
			let c = CGPoint(x: w - 70, y: 36)
			ctx.drawLayer { layer in
				layer.addFilter(.shadow(color: sky.moon.opacity(0.25), radius: 9))
				layer.drawLayer { moon in
					moon.fill(circle(c, 15), with: .color(sky.moon))
					moon.blendMode = .destinationOut
					moon.fill(circle(CGPoint(x: c.x + 9, y: c.y - 5), 15), with: .color(.black))
				}
			}
		}

		switch condition {
		case .rain, .storm:
			for i in 0..<34 {
				let x = w - 200 + CGFloat(unit(i, 1)) * 180
				let fall = (Double(unit(i, 2)) + t / 0.9).truncatingRemainder(dividingBy: 1)
				let y = 64 + CGFloat(fall) * (h - 84)
				var drop = Path()
				drop.move(to: CGPoint(x: x, y: y))
				drop.addLine(to: CGPoint(x: x - 2.5, y: y + 8))
				ctx.stroke(drop, with: .color(sky.rain.opacity(0.75)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
			}
		case .snow:
			for i in 0..<22 {
				let fall = (Double(unit(i, 2)) + t / 4).truncatingRemainder(dividingBy: 1)
				let x = w - 200 + CGFloat(unit(i, 1)) * 180 + 3 * sin(t * 1.3 + Double(i))
				let y = 70 + CGFloat(fall) * (h - 86)
				ctx.fill(circle(CGPoint(x: x, y: y), 1.6), with: .color(sky.cloud.opacity(0.9)))
			}
		default: break
		}

		let cloudColor = condition == .rain || condition == .storm || isNight ? sky.cloudDark : sky.cloud
		for cloud in clouds {
			let drift = 10 * sin(2 * .pi * t / 14 + cloud.phase)
			ctx.fill(cloudPath(x: w + cloud.x + drift, y: cloud.y, width: cloud.w), with: .color(cloudColor))
		}

		if condition == .storm {
			let flash = max(0, 1 - (t.truncatingRemainder(dividingBy: 5)) / 0.18)
			ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.16 * flash)))
		}

		let far = hill(size, base: h - 34, amplitude: 7, period: w * 0.9, phase: 1.2)
		ctx.fill(far, with: .color(isNight ? sky.farHillNight : sky.farHillDay))
		ctx.fill(hill(size, base: h - 16, amplitude: 5, period: w * 0.7, phase: 3.4), with: .color(theme.card))
	}

	private func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
		Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
	}

	// Three arcs over a flat base, on a 64×34 grid.
	private func cloudPath(x: CGFloat, y: CGFloat, width: CGFloat) -> Path {
		let s = width / 64
		var p = Path()
		for (cx, cy, r) in [(CGFloat(16), CGFloat(23), CGFloat(11)), (36, 18, 17), (51, 22, 12)] {
			p.addEllipse(in: CGRect(x: x + (cx - r) * s, y: y + (cy - r) * s, width: 2 * r * s, height: 2 * r * s))
		}
		p.addRoundedRect(
			in: CGRect(x: x + 5 * s, y: y + 22 * s, width: 58 * s, height: 12 * s), cornerSize: CGSize(width: 6 * s, height: 6 * s))
		return p
	}

	private func hill(_ size: CGSize, base: CGFloat, amplitude: CGFloat, period: CGFloat, phase: CGFloat) -> Path {
		var p = Path()
		p.move(to: CGPoint(x: 0, y: size.height))
		for x in stride(from: CGFloat(0), through: size.width, by: 4) {
			p.addLine(to: CGPoint(x: x, y: base + amplitude * sin(2 * .pi * x / period + phase)))
		}
		p.addLine(to: CGPoint(x: size.width, y: size.height))
		p.closeSubpath()
		return p
	}

	// A fixed pseudo-random 0…1 per particle, so drops keep their lanes.
	private func unit(_ i: Int, _ salt: Int) -> Double {
		let v = sin(Double(i * 127 + salt * 311) * 12.9898) * 43758.5453
		return v - v.rounded(.down)
	}
}
