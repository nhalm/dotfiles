import Foundation

enum Messages: String {
	case show = "barpop.show"
	case hide = "barpop.hide"
	case sync = "barpop.sync"

	static func post(_ message: Messages, _ info: [String: String]) {
		DistributedNotificationCenter.default().postNotificationName(
			Notification.Name(message.rawValue), object: nil, userInfo: info, deliverImmediately: true)
	}

	static func observe(_ message: Messages, _ handler: @escaping @MainActor ([String: String]) -> Void) {
		DistributedNotificationCenter.default().addObserver(
			forName: Notification.Name(message.rawValue), object: nil, queue: .main
		) { note in
			let info = note.userInfo as? [String: String] ?? [:]
			MainActor.assumeIsolated { handler(info) }
		}
	}
}
