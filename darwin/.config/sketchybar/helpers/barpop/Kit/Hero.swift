import SwiftUI

// The popup's headline: what it is, its one value, and an optional
// accessory on the right (a HeaderToggle). A sky backdrop bleeds to the
// card's edges behind it.
struct HeroHeader<Accessory: View>: View {
	enum Style { case numeric, text }
	enum Backdrop { case none, sky(SkyCondition, isNight: Bool) }

	@Environment(\.theme) private var theme
	let eyebrow: String
	var eyebrowSymbol: String?
	var eyebrowChip: Chip?
	let value: String
	var unit: String?
	var subtitle: String?
	var subtitleSymbol: String?
	var style = Style.numeric
	var dimmed = false
	var backdrop = Backdrop.none
	@ViewBuilder var accessory: Accessory

	var body: some View {
		content.background(alignment: .top) {
			if case .sky(let condition, let isNight) = backdrop {
				SkyScene(condition: condition, isNight: isNight)
					.padding(.horizontal, -Space.s5)
					.padding(.top, -Space.s5)
					.padding(.bottom, -Space.s4)
			}
		}
	}

	private var secondary: Color {
		if case .sky = backdrop { theme.text.opacity(0.85) } else { theme.textSecondary }
	}

	private var content: some View {
		HStack(alignment: .top, spacing: Space.s4) {
			VStack(alignment: .leading, spacing: Space.s1) {
				HStack(spacing: Space.s1 + 2) {
					if let eyebrowSymbol { Image(systemName: eyebrowSymbol).imageScale(.small) }
					Text(eyebrow).lineLimit(1)
					if let eyebrowChip { eyebrowChip.padding(.leading, Space.s1) }
				}
				.font(Theme.Font.label)
				.foregroundStyle(secondary)
				HStack(alignment: .firstTextBaseline, spacing: 2) {
					Text(value)
						.font(style == .numeric ? Theme.Font.display : Theme.Font.title)
						.tracking(style == .numeric ? Theme.Tracking.display : Theme.Tracking.title)
						.foregroundStyle(dimmed ? secondary : theme.text)
						.lineLimit(1)
						.contentTransition(.numericText())
					if let unit {
						Text(unit).font(Theme.Font.displayUnit).foregroundStyle(secondary)
					}
				}
				.animation(Motion.numeric, value: value)
				if let subtitle {
					HStack(spacing: Space.s1 + 2) {
						if let subtitleSymbol {
							Image(systemName: subtitleSymbol).imageScale(.small).foregroundStyle(theme.accent)
						}
						Text(subtitle).lineLimit(1)
					}
					.font(Theme.Font.label)
					.foregroundStyle(secondary)
				}
			}
			Spacer(minLength: 0)
			accessory
		}
	}
}

extension HeroHeader where Accessory == EmptyView {
	init(
		eyebrow: String, eyebrowSymbol: String? = nil, eyebrowChip: Chip? = nil, value: String, unit: String? = nil,
		subtitle: String? = nil, subtitleSymbol: String? = nil, style: Style = .numeric, dimmed: Bool = false,
		backdrop: Backdrop = .none
	) {
		self.init(
			eyebrow: eyebrow, eyebrowSymbol: eyebrowSymbol, eyebrowChip: eyebrowChip, value: value, unit: unit,
			subtitle: subtitle, subtitleSymbol: subtitleSymbol, style: style, dimmed: dimmed, backdrop: backdrop,
			accessory: { EmptyView() })
	}
}

// The popup's one primary switch, beside the hero value.
struct HeaderToggle: View {
	@Environment(\.theme) private var theme
	@Environment(\.isEnabled) private var isEnabled
	let symbol: String
	var variableValue: Double?
	let isOn: Bool
	// Off, but the user should turn it on: a critical ring that pulses.
	var attention = false
	let label: String
	let action: () -> Void

	var body: some View {
		let alert = attention && !isOn
		Button {
			withAnimation(Motion.toggle) { action() }
		} label: {
			Image(symbol: symbol, variableValue: variableValue)
				.font(.system(size: 17))
				.foregroundStyle(isOn ? theme.onAccent : (alert ? theme.critical : theme.textSecondary))
				.symbolEffect(.bounce, value: isOn)
				.symbolEffect(.pulse, isActive: alert)
				.contentTransition(.symbolEffect(.replace))
				.frame(width: 40, height: 40)
				.background(Circle().fill(isOn ? theme.accent : theme.raised))
				.overlay { if alert { AttentionRing(color: theme.critical) } }
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.opacity(isEnabled ? 1 : 0.4)
		.help(label)
		.accessibilityLabel(label)
	}
}

private struct AttentionRing: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	let color: Color

	var body: some View {
		Circle().strokeBorder(color, lineWidth: 1.5).padding(-2)
			.background {
				if !reduceMotion {
					PhaseAnimator([false, true]) { on in
						Circle().strokeBorder(color, lineWidth: 1.5).padding(-2)
							.scaleEffect(on ? 1.25 : 1)
							.opacity(on ? 0 : 0.45)
					} animation: { on in
						on ? .easeOut(duration: 1.6) : nil
					}
				}
			}
			.allowsHitTesting(false)
	}
}
