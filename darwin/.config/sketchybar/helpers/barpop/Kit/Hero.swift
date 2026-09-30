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
	let value: String
	var unit: String?
	var subtitle: String?
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
					Text(subtitle).font(Theme.Font.label).foregroundStyle(secondary).lineLimit(1)
				}
			}
			Spacer(minLength: 0)
			accessory
		}
	}
}

extension HeroHeader where Accessory == EmptyView {
	init(
		eyebrow: String, eyebrowSymbol: String? = nil, value: String, unit: String? = nil, subtitle: String? = nil,
		style: Style = .numeric, dimmed: Bool = false, backdrop: Backdrop = .none
	) {
		self.init(
			eyebrow: eyebrow, eyebrowSymbol: eyebrowSymbol, value: value, unit: unit, subtitle: subtitle, style: style,
			dimmed: dimmed, backdrop: backdrop, accessory: { EmptyView() })
	}
}

// The popup's one primary switch, beside the hero value.
struct HeaderToggle: View {
	@Environment(\.theme) private var theme
	@Environment(\.isEnabled) private var isEnabled
	let symbol: String
	var variableValue: Double?
	let isOn: Bool
	let label: String
	let action: () -> Void

	var body: some View {
		Button {
			withAnimation(Motion.toggle) { action() }
		} label: {
			Image(systemName: symbol, variableValue: variableValue)
				.font(.system(size: 17))
				.foregroundStyle(isOn ? theme.onAccent : theme.textSecondary)
				.symbolEffect(.bounce, value: isOn)
				.contentTransition(.symbolEffect(.replace))
				.frame(width: 40, height: 40)
				.background(Circle().fill(isOn ? theme.accent : theme.raised))
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.opacity(isEnabled ? 1 : 0.4)
		.help(label)
		.accessibilityLabel(label)
	}
}
