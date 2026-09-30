import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	let palette = Palette()
	let audio = Audio()
	let weather = Weather()
	let battery = Battery()
	let agenda = Agenda()
	let bluetooth = Bluetooth()
	let media = Media()
	let wifi = Wifi()
	private var panel: PopupPanel?
	private var anchor = NSRect.zero
	private var item = ""
	private var mouseTimer: Timer?
	private var outsideSince: Date?
	private var clickMonitor: Any?

	func applicationDidFinishLaunching(_ notification: Notification) {
		MenuBar.showBackground()
		MenuBar.setAlpha(0)
		Messages.observe(.show) { [weak self] info in self?.show(info) }
		Messages.observe(.hide) { [weak self] _ in self?.hide() }
		NSWorkspace.shared.notificationCenter.addObserver(
			forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
		) { [weak self] _ in MainActor.assumeIsolated { self?.reset() } }
	}

	// Display changes and sleep can bring the native menu bar back.
	func applicationDidChangeScreenParameters(_ notification: Notification) { reset() }

	private func reset() {
		MenuBar.setAlpha(0)
		hide()
	}

	private func view(for popup: String) -> AnyView? {
		switch popup {
		case "volume": return AnyView(VolumePopup().environment(audio))
		case "weather":
			weather.refreshIfStale()
			return AnyView(WeatherPopup().environment(weather))
		case "battery":
			battery.sampleEnergy()
			return AnyView(BatteryPopup().environment(battery))
		case "calendar":
			agenda.open()
			return AnyView(CalendarPopup().environment(agenda))
		case "bluetooth":
			bluetooth.refresh()
			return AnyView(BluetoothPopup().environment(bluetooth))
		case "media": return AnyView(MediaPopup().environment(media))
		case "wifi": return AnyView(WifiPopup().environment(wifi))
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
		item = info["item"] ?? ""
		Shell.trigger("barpop_popup", ["ITEM": item, "OPEN": "1"])
		let panel = PopupPanel(name: name, content: content, palette: palette)
		panel.presentation.close = { [weak self] in self?.hide() }
		panel.onResize = { [weak self, weak panel] in
			guard let self, let panel, panel === self.panel else { return }
			self.place(panel, on: screen)
		}
		place(panel, on: screen)
		panel.orderFrontRegardless()
		self.panel = panel
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
	// it may overhang them. The panel's top meets the item's rect, so the
	// card's top margin is the gap below the bar.
	private func place(_ panel: PopupPanel, on screen: NSScreen) {
		let size = panel.fittingSize
		let m = PopupPanel.margin
		let x = min(
			max(anchor.midX - size.width / 2, screen.frame.minX + 8 - m.leading),
			screen.frame.maxX - 8 + m.trailing - size.width)
		panel.setFrame(NSRect(x: x, y: anchor.minY - size.height, width: size.width, height: size.height), display: true)
		panel.presentation.anchorX = anchor.midX - x - m.leading
	}

	private func hide() {
		mouseTimer?.invalidate()
		mouseTimer = nil
		if let m = clickMonitor { NSEvent.removeMonitor(m) }
		clickMonitor = nil
		outsideSince = nil
		guard let panel else { return }
		self.panel = nil
		Shell.trigger("barpop_popup", ["ITEM": item, "OPEN": "0"])
		panel.ignoresMouseEvents = true
		panel.presentation.dismiss { panel.orderOut(nil) }
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
	// Room around the card for its shadow. The top is the card's gap below
	// the item: the bar's 4pt beyond its items plus 6pt, which the opening
	// tab spans to touch the bar.
	static let margin = EdgeInsets(top: 10, leading: 16, bottom: 24, trailing: 16)

	let name: String
	let presentation = Presentation()
	var onResize: (() -> Void)?
	private var host: NSHostingController<AnyView>?

	init(name: String, content: AnyView, palette: Palette) {
		self.name = name
		super.init(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
		let root = Themed { content }
			.environment(palette)
			.environment(presentation)
			.fixedSize()
			.onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] _ in self?.onResize?() }
			.padding(Self.margin)
		let host = NSHostingController(rootView: AnyView(root))
		host.sizingOptions = []
		self.host = host
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
	var fittingSize: NSSize { host?.sizeThatFits(in: NSSize(width: 10_000, height: 10_000)) ?? .zero }

	override var canBecomeKey: Bool { true }

	override func cancelOperation(_ sender: Any?) { presentation.close() }
}
