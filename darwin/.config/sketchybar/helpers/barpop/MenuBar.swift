import Foundation

// The native menu bar's opacity, through the private SkyLight call yabai's
// menubar_opacity uses. At 0 the auto-hidden bar stays invisible and ignores
// the mouse when the pointer reaches the top edge. It holds only while this
// process runs, so the native bar returns if barpop quits.
enum MenuBar {
	private typealias Connection = @convention(c) () -> Int32
	private typealias SetAlpha = @convention(c) (Int32, Double, Double, Float) -> Int32
	private typealias GetBackground = @convention(c) () -> Bool
	private typealias SetBackground = @convention(c) (Bool, Bool) -> Void

	// AppKit already loads SkyLight, so RTLD_DEFAULT finds its symbols.
	private nonisolated(unsafe) static let lib = UnsafeMutableRawPointer(bitPattern: -2)

	static func setAlpha(_ alpha: Float) {
		guard let conn = dlsym(lib, "SLSMainConnectionID"), let set = dlsym(lib, "SLSSetMenuBarInsetAndAlpha")
		else { return }
		let connection = unsafeBitCast(conn, to: Connection.self)
		_ = unsafeBitCast(set, to: SetAlpha.self)(connection(), 0, 1, alpha)
	}

	// With "Show menu bar background" off, WindowServer fades in its own
	// underbelly window, a glow over the top of the wallpaper, on every reveal.
	// The alpha never reaches it; turning the background on removes it.
	static func showBackground() {
		guard let get = dlsym(lib, "SLSGetMenuBarUseBlurredAppearance"),
			let set = dlsym(lib, "SLSSetMenuBarUseBlurredAppearance"),
			!unsafeBitCast(get, to: GetBackground.self)()
		else { return }
		unsafeBitCast(set, to: SetBackground.self)(true, true)
	}
}
