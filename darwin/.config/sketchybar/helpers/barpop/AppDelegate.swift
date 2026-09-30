import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	let palette = Palette()
	let audio = Audio()
	private var panel: PopupPanel?
	private var screen: NSScreen?
	private var anchor = NSRect.zero
	private var mouseTimer: Timer?
	private var outsideSince: Date?
	private var clickMonitor: Any?

	func applicationDidFinishLaunching(_ notification: Notification) {
		MenuBar.setAlpha(0)
		Messages.observe(.show) { [weak self] info in self?.show(info) }
		Messages.observe(.hide) { [weak self] _ in self?.hide() }
		NSWorkspace.shared.notificationCenter.addObserver(
			forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
		) { [weak self] _ in MainActor.assumeIsolated { self?.reset() } }
		trackDevices()
	}

	// Display changes and sleep can bring the native menu bar back.
	func applicationDidChangeScreenParameters(_ notification: Notification) { reset() }

	private func reset() {
		MenuBar.setAlpha(0)
		hide()
	}

	private func view(for popup: String) -> AnyView? {
		switch popup {
		case "volume": return AnyView(VolumeView().environment(palette).environment(audio))
		default: return nil
		}
	}

	private func show(_ info: [String: String]) {
		guard let name = info["popup"], let content = view(for: name) else { return }
		let mouse = NSEvent.mouseLocation
		let distance = { (r: NSRect) in
			hypot(max(r.minX - mouse.x, 0, mouse.x - r.maxX), max(r.minY - mouse.y, 0, mouse.y - r.maxY))
		}
		guard let rect = rects(info["rects"] ?? "").min(by: { distance($0) < distance($1) }),
			let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) })
		else { return }
		if panel?.name == name && anchor == rect {
			hide()
			return
		}
		hide()

		anchor = rect
		let panel = PopupPanel(name: name, content: content)
		panel.onCancel = { [weak self] in self?.hide() }
		place(panel, on: screen)
		panel.orderFrontRegardless()
		self.panel = panel
		self.screen = screen
		startTracking()
	}

	// sketchybar reports the item's rect on each display in global
	// CoreGraphics coordinates, top-left of the primary display at 0,0.
	private func rects(_ spec: String) -> [NSRect] {
		guard let top = NSScreen.screens.first?.frame.maxY else { return [] }
		return spec.split(separator: ";").compactMap { part in
			let v = part.split(separator: ",").compactMap { Double($0) }
			guard v.count == 4 else { return nil }
			return NSRect(x: v[0], y: top - v[1] - v[3], width: v[2], height: v[3])
		}
	}

	// The card keeps 8pt from the screen edges; the transparent margin around
	// it may overhang them.
	private func place(_ panel: PopupPanel, on screen: NSScreen) {
		let size = panel.fittingSize
		let edge = 8 - PopupPanel.margin
		let x = min(max(anchor.midX - size.width / 2, screen.frame.minX + edge), screen.frame.maxX - edge - size.width)
		panel.setFrame(
			NSRect(x: x, y: anchor.minY - 6 - size.height, width: size.width, height: size.height), display: true)
	}

	private func trackDevices() {
		withObservationTracking { _ = audio.devices } onChange: { [weak self] in
			Task { @MainActor in
				guard let self else { return }
				if let panel = self.panel, let screen = self.screen { self.place(panel, on: screen) }
				self.trackDevices()
			}
		}
	}

	private func hide() {
		mouseTimer?.invalidate()
		mouseTimer = nil
		if let m = clickMonitor { NSEvent.removeMonitor(m) }
		clickMonitor = nil
		outsideSince = nil
		guard let panel else { return }
		self.panel = nil
		panel.ignoresMouseEvents = true
		NSAnimationContext.runAnimationGroup { ctx in
			ctx.duration = 0.12
			panel.animator().alphaValue = 0
		} completionHandler: {
			MainActor.assumeIsolated { panel.orderOut(nil) }
		}
	}

	private func startTracking() {
		let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
			MainActor.assumeIsolated { self?.track() }
		}
		RunLoop.main.add(timer, forMode: .common)
		mouseTimer = timer
		clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
			[weak self] _ in MainActor.assumeIsolated { self?.clicked() }
		}
	}

	// Polling the pointer needs no permission, unlike a global mouse-moved
	// monitor. The strip between the item and the panel counts as inside, so
	// crossing it does not close anything, and so does a drag that strays out.
	private func track() {
		guard let panel else { return }
		let bridge = NSRect(
			x: min(anchor.minX, panel.frame.minX), y: panel.frame.maxY,
			width: max(anchor.maxX, panel.frame.maxX) - min(anchor.minX, panel.frame.minX),
			height: anchor.minY - panel.frame.maxY)
		let mouse = NSEvent.mouseLocation
		let inside = NSEvent.pressedMouseButtons != 0 || [anchor, panel.frame, bridge].contains {
			NSMouseInRect(mouse, $0.insetBy(dx: -2, dy: -2), false)
		}
		if inside {
			outsideSince = nil
		} else if let since = outsideSince {
			if Date().timeIntervalSince(since) > 0.3 { hide() }
		} else {
			outsideSince = Date()
		}
	}

	private func clicked() {
		guard let panel else { return }
		let mouse = NSEvent.mouseLocation
		if !NSMouseInRect(mouse, panel.frame, false) && !NSMouseInRect(mouse, anchor, false) { hide() }
	}
}

// Non-activating, so opening it never steals focus from the app you're in.
@MainActor
final class PopupPanel: NSPanel {
	// Room around the card for its shadow.
	static let margin: CGFloat = 20

	let name: String
	var onCancel: (() -> Void)?
	private let host: NSHostingController<AnyView>

	init(name: String, content: AnyView) {
		self.name = name
		host = NSHostingController(rootView: AnyView(content.padding(Self.margin)))
		host.sizingOptions = []
		super.init(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
		isFloatingPanel = true
		level = .popUpMenu
		collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
		backgroundColor = .clear
		isOpaque = false
		hasShadow = false
		hidesOnDeactivate = false
		contentView = host.view
	}

	// Sized by the caller, so the top edge stays put when the content grows.
	var fittingSize: NSSize { host.sizeThatFits(in: NSSize(width: 10_000, height: 10_000)) }

	override var canBecomeKey: Bool { true }

	override func cancelOperation(_ sender: Any?) { onCancel?() }
}
