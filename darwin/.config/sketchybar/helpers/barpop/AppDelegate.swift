import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
	let palette = Palette()
	let audio = Audio()
	private var panel: PopupPanel?
	private var anchor = NSRect.zero
	private var mouseTimer: Timer?
	private var outsideSince: Date?
	private var clickMonitor: Any?

	func applicationDidFinishLaunching(_ notification: Notification) {
		MenuBar.setAlpha(0)
		Messages.observe(.show) { [weak self] info in self?.show(info) }
		Messages.observe(.hide) { [weak self] _ in self?.hide() }
	}

	private func view(for popup: String) -> AnyView? {
		switch popup {
		case "volume": return AnyView(VolumeView().environmentObject(palette).environmentObject(audio))
		default: return nil
		}
	}

	// x and width are the item's sketchybar bounds, relative to the display
	// the click came from.
	private func show(_ info: [String: String]) {
		guard let name = info["popup"], let content = view(for: name),
			let x = Double(info["x"] ?? ""), let width = Double(info["width"] ?? "")
		else { return }
		if panel?.isVisible == true && panel?.name == name {
			hide()
			return
		}
		hide()

		let mouse = NSEvent.mouseLocation
		guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
		else { return }
		let barHeight: CGFloat = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 36
		anchor = NSRect(
			x: screen.frame.minX + x, y: screen.frame.maxY - barHeight, width: width, height: barHeight)

		let panel = PopupPanel(name: name, content: content)
		let size = panel.contentView?.fittingSize ?? NSSize(width: 300, height: 200)
		var origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.minY - 6 - size.height)
		origin.x = min(max(origin.x, screen.frame.minX + 8), screen.frame.maxX - 8 - size.width)
		panel.setFrame(NSRect(origin: origin, size: size), display: true)
		panel.orderFrontRegardless()
		self.panel = panel
		startTracking()
	}

	private func hide() {
		mouseTimer?.invalidate()
		mouseTimer = nil
		if let m = clickMonitor { NSEvent.removeMonitor(m) }
		clickMonitor = nil
		outsideSince = nil
		panel?.orderOut(nil)
		panel = nil
	}

	// Polling the pointer needs no permission, unlike a global mouse-moved
	// monitor. The strip between the item and the panel counts as inside, so
	// crossing it does not close anything.
	private func startTracking() {
		mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
			guard let self, let panel = self.panel else { return }
			let bridge = NSRect(
				x: min(self.anchor.minX, panel.frame.minX), y: panel.frame.maxY,
				width: max(self.anchor.maxX, panel.frame.maxX) - min(self.anchor.minX, panel.frame.minX),
				height: self.anchor.minY - panel.frame.maxY)
			let inside = [self.anchor, panel.frame, bridge].contains {
				NSMouseInRect(NSEvent.mouseLocation, $0.insetBy(dx: -2, dy: -2), false)
			}
			if inside {
				self.outsideSince = nil
			} else if let since = self.outsideSince {
				if Date().timeIntervalSince(since) > 0.3 { self.hide() }
			} else {
				self.outsideSince = Date()
			}
		}
		clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
			[weak self] _ in
			guard let self, let panel = self.panel else { return }
			if !NSMouseInRect(NSEvent.mouseLocation, panel.frame, false)
				&& !NSMouseInRect(NSEvent.mouseLocation, self.anchor, false)
			{
				self.hide()
			}
		}
	}
}

// Non-activating, so opening it never steals focus from the app you're in.
final class PopupPanel: NSPanel {
	let name: String

	init(name: String, content: AnyView) {
		self.name = name
		super.init(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
		isFloatingPanel = true
		level = .popUpMenu
		collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
		backgroundColor = .clear
		isOpaque = false
		hasShadow = false
		hidesOnDeactivate = false
		let host = NSHostingView(rootView: content)
		host.sizingOptions = [.intrinsicContentSize]
		contentView = host
	}

	override var canBecomeKey: Bool { true }
}
