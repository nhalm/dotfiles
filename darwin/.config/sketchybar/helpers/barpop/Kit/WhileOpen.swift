import SwiftUI

extension View {
	// Runs work, e.g. live sampling, from when the popup opens until it
	// starts closing; the panel's views outlive the popup, so onDisappear
	// and task alone never end.
	func whileOpen(_ work: @escaping @MainActor @Sendable () async -> Void) -> some View {
		modifier(WhileOpen(work: work))
	}
}

private struct WhileOpen: ViewModifier {
	@Environment(Presentation.self) private var presentation
	let work: @MainActor @Sendable () async -> Void

	func body(content: Content) -> some View {
		content.task(id: presentation.revealed) {
			if presentation.revealed { await work() }
		}
	}
}
