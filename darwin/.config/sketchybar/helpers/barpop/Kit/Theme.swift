import SwiftUI

// Semantic tokens over the matugen roles. Kit components read only these;
// popups read neither, they compose the kit.
struct Theme {
	let card: Color
	let raised: Color
	let pressed: Color
	let deep: Color
	let text: Color
	let textSecondary: Color
	let textTertiary: Color
	let accent: Color
	let onAccent: Color
	let accentSoft: Color
	let onAccentSoft: Color
	let accentAlt: Color
	let hairline: Color
	let separator: Color
	let critical: Color
	init(_ r: Roles = Roles()) {
		card = r.surfaceContainer
		raised = r.surfaceContainerHigh
		pressed = r.surfaceContainerHighest
		deep = r.surface
		text = r.onSurface
		textSecondary = r.onSurfaceVariant
		textTertiary = r.onSurfaceVariant.opacity(0.4)
		accent = r.primary
		onAccent = r.onPrimary
		accentSoft = r.primaryContainer
		onAccentSoft = r.onPrimaryContainer
		accentAlt = r.tertiary
		hairline = r.outlineVariant.opacity(0.7)
		separator = r.outlineVariant.opacity(0.6)
		critical = r.error
	}

	enum Font {
		static let display = SwiftUI.Font.system(size: 44, weight: .light, design: .rounded).monospacedDigit()
		static let displayUnit = SwiftUI.Font.system(size: 22, weight: .light, design: .rounded)
		static let title = SwiftUI.Font.system(size: 22)
		static let headline = SwiftUI.Font.system(size: 17, design: .rounded).monospacedDigit()
		static let emptyTitle = SwiftUI.Font.system(size: 15)
		static let body = SwiftUI.Font.system(size: 13)
		static let label = SwiftUI.Font.system(size: 12)
		static let caption = SwiftUI.Font.system(size: 11)
	}

	enum Tracking {
		static let display: CGFloat = -0.9
		static let title: CGFloat = -0.2
	}
}

enum Space {
	static let s1: CGFloat = 4
	static let s2: CGFloat = 8
	static let s3: CGFloat = 12
	static let s4: CGFloat = 16
	static let s5: CGFloat = 20
}

enum Radius {
	static let card: CGFloat = 22
	static let tile: CGFloat = 14
	static let row: CGFloat = 10
	static let icon: CGFloat = 8
}

enum Motion {
	static let emerge = Animation.spring(response: 0.38, dampingFraction: 0.84)
	static let light = Animation.easeOut(duration: 0.5).delay(0.06)
	static let collapseContent = Animation.easeIn(duration: 0.08)
	static let collapseShape = Animation.easeIn(duration: 0.16).delay(0.08)
	static let collapseDuration = 0.26
	static let fade = Animation.easeOut(duration: 0.15)
	static let numeric = Animation.snappy(duration: 0.22)
	static let hover = Animation.easeOut(duration: 0.12)
	static let engage = Animation.spring(response: 0.25, dampingFraction: 0.8)
	static let toggle = Animation.spring(response: 0.3, dampingFraction: 0.7)
	static let select = Animation.spring(response: 0.3, dampingFraction: 0.75)
	static let palette = Animation.easeInOut(duration: 0.45)

	// Top-level card children fade up in turn once the shape is ~60% open.
	static func stagger(_ index: Int) -> Animation {
		.easeOut(duration: 0.22).delay(0.1 + 0.035 * Double(min(index, 4)))
	}
}

private struct ThemeKey: EnvironmentKey {
	static let defaultValue = Theme()
}

extension EnvironmentValues {
	var theme: Theme {
		get { self[ThemeKey.self] }
		set { self[ThemeKey.self] = newValue }
	}
}

// Rebuilds the tokens whenever matugen rewrites the palette.
struct Themed<Content: View>: View {
	@Environment(Palette.self) private var palette
	@ViewBuilder let content: Content

	var body: some View {
		content.environment(\.theme, Theme(palette.roles))
	}
}
