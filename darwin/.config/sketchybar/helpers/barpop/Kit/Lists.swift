import SwiftUI

struct SectionLabel: View {
	@Environment(\.theme) private var theme
	let title: String
	var trailing: String?
	var accessory: AnyView?

	init(_ title: String, trailing: String? = nil) {
		self.title = title
		self.trailing = trailing
	}

	init(_ title: String, @ViewBuilder accessory: () -> some View) {
		self.title = title
		self.accessory = AnyView(HStack(spacing: Space.s1) { accessory() })
	}

	var body: some View {
		HStack {
			Text(title)
			Spacer(minLength: Space.s2)
			if let trailing { Text(trailing).lineLimit(1) }
			accessory
		}
		.font(Theme.Font.label)
		.foregroundStyle(theme.textSecondary)
	}
}

// A labelled group of rows or content, spaced for the card. Consecutive
// ValueRows get a hairline between them.
struct Section<Content: View>: View {
	@Environment(\.theme) private var theme
	let label: String
	var trailing: String?
	var accessory: AnyView?
	@ViewBuilder let content: Content

	init(_ label: String, trailing: String? = nil, @ViewBuilder content: () -> Content) {
		self.label = label
		self.trailing = trailing
		self.content = content()
	}

	init(_ label: String, @ViewBuilder content: () -> Content, @ViewBuilder trailing: () -> some View) {
		self.label = label
		self.content = content()
		accessory = AnyView(trailing())
	}

	var body: some View {
		VStack(alignment: .leading, spacing: Space.s2) {
			if let accessory { SectionLabel(label) { accessory } } else { SectionLabel(label, trailing: trailing) }
			Group(subviews: content) { rows in
				VStack(alignment: .leading, spacing: 0) {
					ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
						if i > 0 {
							if rows[i - 1].containerValues.divided && row.containerValues.divided {
								Rectangle().fill(theme.separator).frame(height: 1)
							} else {
								Color.clear.frame(height: 2)
							}
						}
						row
					}
				}
			}
		}
	}
}

// Something to choose: a device, a network, an action.
struct ListItem: View {
	@Environment(\.theme) private var theme
	let title: String
	var subtitle: String?
	let symbol: String
	// An app's own icon, in place of the symbol tile.
	var icon: NSImage?
	var isSelected = false
	var variableValue: Double?
	// A trailing glyph, e.g. a lock; hoverChip replaces it while hovered.
	var trailingSymbol: String?
	var hoverChip: String?
	let action: () -> Void
	@State private var hovering = false

	var body: some View {
		Button(action: action) {
			HStack(spacing: Space.s3) {
				if let icon {
					AppIcon(image: icon)
				} else {
					IconTile(
						symbol: symbol, tone: isSelected ? .accent : .neutral, lifted: hovering, variableValue: variableValue)
				}
				VStack(alignment: .leading, spacing: 1) {
					Text(title).font(Theme.Font.body).foregroundStyle(theme.text).lineLimit(1)
					if let subtitle {
						Text(subtitle).font(Theme.Font.caption).foregroundStyle(theme.textSecondary).lineLimit(1)
					}
				}
				Spacer(minLength: 0)
				if isSelected {
					Image(systemName: "checkmark")
						.font(Theme.Font.caption)
						.foregroundStyle(theme.accent)
						.transition(.scale(scale: 0.6).combined(with: .opacity))
				} else if hovering, let hoverChip {
					Chip(hoverChip)
				} else if let trailingSymbol {
					Image(systemName: trailingSymbol).font(Theme.Font.body).foregroundStyle(theme.textSecondary)
				}
			}
			.frame(minHeight: 44)
			.contentShape(Rectangle())
		}
		.buttonStyle(RowStyle(hovering: hovering))
		.onHover { hovering = $0 }
		.animation(Motion.hover, value: hovering)
		.animation(Motion.select, value: isSelected)
	}
}

// The hover pill bleeds past the content edge so text stays on it.
struct RowStyle: ButtonStyle {
	@Environment(\.theme) private var theme
	let hovering: Bool

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.padding(.horizontal, Space.s2)
			.background(
				configuration.isPressed ? theme.pressed : (hovering ? theme.raised : .clear),
				in: .rect(cornerRadius: Radius.row, style: .continuous)
			)
			.padding(.horizontal, -Space.s2)
	}
}

struct IconTile: View {
	enum Tone { case neutral, accent }

	@Environment(\.theme) private var theme
	let symbol: String
	var tone = Tone.neutral
	// Inside a hovered row the neutral tile steps up so it stays visible.
	var lifted = false
	var variableValue: Double?

	var body: some View {
		Image(systemName: symbol, variableValue: variableValue)
			.font(.system(size: 13))
			.foregroundStyle(tone == .accent ? theme.onAccentSoft : theme.textSecondary)
			.frame(width: 28, height: 28)
			.background(
				tone == .accent ? theme.accentSoft : (lifted ? theme.pressed : theme.raised),
				in: .rect(cornerRadius: Radius.icon, style: .continuous))
	}
}

// A fact: label on the left, its value on the right, 36pt.
struct ValueRow<Value: View>: View {
	@Environment(\.theme) private var theme
	let label: String
	var symbol: String?
	var note: String?
	@ViewBuilder let value: Value

	init(_ label: String, symbol: String? = nil, note: String? = nil, @ViewBuilder value: () -> Value) {
		self.label = label
		self.symbol = symbol
		self.note = note
		self.value = value()
	}

	var body: some View {
		HStack(spacing: Space.s3) {
			Text(label).frame(minWidth: symbol == nil ? nil : 44, alignment: .leading)
			if let symbol {
				Image(systemName: symbol).foregroundStyle(theme.textSecondary).frame(width: 20)
			}
			if let note { Text(note).font(Theme.Font.caption).foregroundStyle(theme.accentAlt) }
			Spacer(minLength: Space.s2)
			value
		}
		.font(Theme.Font.body)
		.lineLimit(1)
		.frame(minHeight: 36)
		.containerValue(\.divided, true)
	}
}

private struct DividedKey: ContainerValueKey {
	static let defaultValue = false
}

extension ContainerValues {
	var divided: Bool {
		get { self[DividedKey.self] }
		set { self[DividedKey.self] = newValue }
	}
}

// Replaces the hero and sections when there is nothing to show.
struct EmptyState: View {
	@Environment(\.theme) private var theme
	let symbol: String
	let title: String
	var message: String?
	var action: (title: String, run: () -> Void)?

	var body: some View {
		VStack(spacing: Space.s3) {
			Image(systemName: symbol)
				.font(.system(size: 20))
				.foregroundStyle(theme.textSecondary)
				.frame(width: 48, height: 48)
				.background(Circle().fill(theme.raised))
			VStack(spacing: Space.s1) {
				Text(title).font(Theme.Font.emptyTitle)
				if let message {
					Text(message).font(Theme.Font.label).foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
				}
			}
			if let action {
				Button(action: action.run) { Chip(action.title) }.buttonStyle(.plain)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, Space.s4)
	}
}

struct Chip: View {
	enum Tone { case accent, critical }

	@Environment(\.theme) private var theme
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	let text: String
	let tone: Tone
	// Something under way, e.g. "Applying…".
	let pulsing: Bool

	init(_ text: String, tone: Tone = .accent, pulsing: Bool = false) {
		self.text = text
		self.tone = tone
		self.pulsing = pulsing
	}

	var body: some View {
		let (fg, bg): (Color, Color) =
			switch tone {
			case .accent: (theme.onAccentSoft, theme.accentSoft)
			case .critical: (theme.critical, theme.critical.opacity(0.18))
			}
		let chip = Text(text)
			.font(Theme.Font.caption)
			.foregroundStyle(fg)
			.padding(.horizontal, Space.s2 + 2)
			.frame(height: 20)
			.background(Capsule().fill(bg))
		if pulsing && !reduceMotion {
			PhaseAnimator([1, 0.5]) { chip.opacity($0) } animation: { _ in .easeInOut(duration: 0.8) }
		} else {
			chip
		}
	}
}

// The card's last line: where to go for more. Closes the popup.
struct FooterLink: View {
	@Environment(\.theme) private var theme
	@Environment(Presentation.self) private var presentation
	let title: String
	var detail: String?
	let action: () -> Void
	@State private var hovering = false

	init(_ title: String, detail: String? = nil, action: @escaping () -> Void) {
		self.title = title
		self.detail = detail
		self.action = action
	}

	var body: some View {
		VStack(spacing: Space.s3) {
			Rectangle().fill(theme.separator).frame(height: 1)
			Button {
				action()
				presentation.close()
			} label: {
				HStack(spacing: Space.s2) {
					Text(title).foregroundStyle(hovering ? theme.text : theme.textSecondary)
					Spacer(minLength: Space.s2)
					if let detail { Text(detail).font(Theme.Font.caption).foregroundStyle(theme.textSecondary) }
					Image(systemName: "chevron.right").font(Theme.Font.caption).foregroundStyle(theme.textSecondary)
				}
				.font(Theme.Font.body)
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.onHover { hovering = $0 }
			.animation(Motion.hover, value: hovering)
		}
		.padding(.top, Space.s4 - Space.s5)
	}
}
