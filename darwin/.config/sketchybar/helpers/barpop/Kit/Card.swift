import AppKit
import SwiftUI

// A panel's open/close state. The panel keeps its final size throughout;
// only the card's shape grows out of the bar icon and back into it.
@MainActor
@Observable
final class Presentation {
	// The icon's center in the card's coordinates.
	var anchorX: CGFloat = 0
	private(set) var progress: CGFloat = 0
	private(set) var revealed = false
	private(set) var opacity: Double
	let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
	@ObservationIgnored var close: () -> Void = {}

	init() { opacity = reduceMotion ? 0 : 1 }

	func present() {
		guard !reduceMotion else {
			progress = 1
			revealed = true
			withAnimation(Motion.fade) { opacity = 1 }
			return
		}
		withAnimation(Motion.emerge) { progress = 1 }
		revealed = true
	}

	func dismiss(_ done: @escaping @MainActor () -> Void) {
		if reduceMotion {
			withAnimation(Motion.fade) { opacity = 0 }
		} else {
			withAnimation(Motion.collapseContent) { revealed = false }
			withAnimation(Motion.collapseShape) { progress = 0 }
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + Motion.collapseDuration) { MainActor.assumeIsolated(done) }
	}
}

struct PopupCard<Content: View>: View {
	enum Width: CGFloat {
		case regular = 320
		case wide = 340
	}

	@Environment(\.theme) private var theme
	@Environment(Presentation.self) private var presentation
	let width: Width
	@ViewBuilder let content: Content

	var body: some View {
		let p = presentation
		let shape = EmergeShape(progress: p.progress, anchorX: p.anchorX)
		Group(subviews: content) { children in
			VStack(alignment: .leading, spacing: Space.s5) {
				ForEach(Array(children.enumerated()), id: \.element.id) { i, child in
					child
						.opacity(p.revealed ? 1 : 0)
						.offset(y: p.revealed ? 0 : 4)
						.animation(
							p.reduceMotion ? nil : (p.revealed ? Motion.stagger(i) : Motion.collapseContent),
							value: p.revealed)
				}
			}
		}
		.padding(Space.s5)
		.frame(width: width.rawValue, alignment: .leading)
		.background(AnchorLight(anchorX: p.anchorX, lit: p.revealed, part: .wash))
		.mask(shape)
		.overlay(AnchorLight(anchorX: p.anchorX, lit: p.revealed, part: .seam).mask(shape))
		.background {
			shape
				.fill(theme.card.mix(with: theme.accent, by: 0.22 * (1 - min(p.progress, 1))))
				.shadow(color: .black.opacity(0.55 * p.progress), radius: 12, y: 8)
				.shadow(color: .black.opacity(0.3 * p.progress), radius: 3, y: 1)
		}
		.overlay {
			shape.strokeBorder(theme.hairline, lineWidth: 1)
			shape.inset(by: 1).stroke(
				LinearGradient(
					colors: [.white.opacity(0.035), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.05)),
				lineWidth: 1)
		}
		.opacity(p.opacity)
		.foregroundStyle(theme.text)
		.font(Theme.Font.body)
		.onAppear { p.present() }
	}
}

// The card's top hairline lit under the icon that opened it, and a faint
// wash of accent falling from there into the card.
private struct AnchorLight: View {
	enum Part { case seam, wash }

	@Environment(\.theme) private var theme
	@Environment(Presentation.self) private var presentation
	let anchorX: CGFloat
	let lit: Bool
	let part: Part

	var body: some View {
		GeometryReader { geo in
			let w = max(geo.size.width, 1)
			switch part {
			case .seam:
				Rectangle()
					.fill(
						LinearGradient(
							colors: [.clear, theme.accent.opacity(0.9), .clear],
							startPoint: UnitPoint(x: (anchorX - 120) / w, y: 0),
							endPoint: UnitPoint(x: (anchorX + 120) / w, y: 0))
					)
					.frame(height: 1)
					.scaleEffect(x: lit ? 1 : 0, anchor: UnitPoint(x: anchorX / w, y: 0))
			case .wash:
				RadialGradient(
					colors: [theme.accent.opacity(0.1), .clear], center: UnitPoint(x: anchorX / w, y: 0),
					startRadius: 0, endRadius: 200
				)
				.scaleEffect(y: 0.6, anchor: .top)
				.opacity(lit ? 1 : 0)
			}
		}
		.animation(presentation.reduceMotion ? nil : (lit ? Motion.light : Motion.collapseContent), value: lit)
		.allowsHitTesting(false)
	}
}

// The card's outline at each stage of opening: a 28×4 tab touching the bar,
// a 112×26 pill, the full width at 42% height, then the whole card.
struct EmergeShape: InsettableShape {
	var progress: CGFloat
	var anchorX: CGFloat
	var inset: CGFloat = 0

	var animatableData: CGFloat {
		get { progress }
		set { progress = newValue }
	}

	func inset(by amount: CGFloat) -> EmergeShape {
		var s = self
		s.inset += amount
		return s
	}

	func path(in r: CGRect) -> Path {
		typealias Key = (p: CGFloat, w: CGFloat, h: CGFloat, y: CGFloat, x: CGFloat, radius: CGFloat)
		let keys: [Key] = [
			(0, 28, 4, -6, anchorX, 2),
			(0.2, 112, 26, -2, anchorX, 13),
			(0.6, r.width, r.height * 0.42, 0, r.width / 2, Radius.card),
			(1, r.width, r.height, 0, r.width / 2, Radius.card),
		]
		let p = min(max(progress, 0), 1)
		let i = min(keys.lastIndex { $0.p <= p } ?? 0, keys.count - 2)
		let a = keys[i]
		let b = keys[i + 1]
		let t = (p - a.p) / (b.p - a.p)
		func mix(_ u: CGFloat, _ v: CGFloat) -> CGFloat { u + (v - u) * t }
		let w = mix(a.w, b.w)
		let h = mix(a.h, b.h)
		let x = min(max(mix(a.x, b.x), w / 2), r.width - w / 2)
		let frame = CGRect(x: r.minX + x - w / 2, y: r.minY + mix(a.y, b.y), width: w, height: h)
			.insetBy(dx: inset, dy: inset)
		let radius = min(mix(a.radius, b.radius), h / 2) - inset
		return Path(roundedRect: frame, cornerRadius: max(radius, 0), style: .continuous)
	}
}
