import SwiftUI

struct SectionLabel: View {
	@Environment(\.theme) private var theme
	let title: String
	var trailing: String?

	init(_ title: String, trailing: String? = nil) {
		self.title = title
		self.trailing = trailing
	}

	var body: some View {
		HStack {
			Text(title)
			Spacer(minLength: Space.s2)
			if let trailing { Text(trailing).lineLimit(1) }
		}
		.font(Theme.Font.label)
		.foregroundStyle(theme.textSecondary)
	}
}

// A labelled group of rows or content, spaced for the card.
struct Section<Content: View>: View {
	let label: String
	var trailing: String?
	@ViewBuilder let content: Content

	init(_ label: String, trailing: String? = nil, @ViewBuilder content: () -> Content) {
		self.label = label
		self.trailing = trailing
		self.content = content()
	}

	var body: some View {
		VStack(alignment: .leading, spacing: Space.s2) {
			SectionLabel(label, trailing: trailing)
			VStack(alignment: .leading, spacing: 2) { content }
		}
	}
}

// Something to choose: a device, a network, an action.
struct ListItem: View {
	@Environment(\.theme) private var theme
	let title: String
	var subtitle: String?
	let symbol: String
	var isSelected = false
	let action: () -> Void
	@State private var hovering = false

	var body: some View {
		Button(action: action) {
			HStack(spacing: Space.s3) {
				IconTile(symbol: symbol, tone: isSelected ? .accent : .neutral, lifted: hovering)
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
private struct RowStyle: ButtonStyle {
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

	var body: some View {
		Image(systemName: symbol)
			.font(.system(size: 13))
			.foregroundStyle(tone == .accent ? theme.onAccentSoft : theme.textSecondary)
			.frame(width: 28, height: 28)
			.background(
				tone == .accent ? theme.accentSoft : (lifted ? theme.pressed : theme.raised),
				in: .rect(cornerRadius: Radius.icon, style: .continuous))
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
