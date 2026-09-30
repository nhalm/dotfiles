import Foundation

// The native menu bar's opacity, through the private SkyLight call yabai's
// menubar_opacity uses. At 0 the auto-hidden bar stays invisible and ignores
// the mouse when the pointer reaches the top edge. It holds only while this
// process runs, so the native bar returns if barpop quits.
enum MenuBar {
	private typealias Connection = @convention(c) () -> Int32
	private typealias SetAlpha = @convention(c) (Int32, Double, Double, Float) -> Int32

	// AppKit already loads SkyLight, so RTLD_DEFAULT finds its symbols.
	static func setAlpha(_ alpha: Float) {
		let lib = UnsafeMutableRawPointer(bitPattern: -2)
		guard let conn = dlsym(lib, "SLSMainConnectionID"), let set = dlsym(lib, "SLSSetMenuBarInsetAndAlpha")
		else { return }
		let connection = unsafeBitCast(conn, to: Connection.self)
		_ = unsafeBitCast(set, to: SetAlpha.self)(connection(), 0, 1, alpha)
	}
}
