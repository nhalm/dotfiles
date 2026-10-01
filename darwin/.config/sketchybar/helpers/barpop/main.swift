import AppKit

// barpop draws sketchybar's richer popups in its own panel, and keeps the
// native menu bar from showing over the bar.
//   barpop daemon <pid>              run the app until sketchybar (pid) exits
//   barpop show <name> <rects> <item> [keyboard]
//                                    open a popup under a sketchybar item; rects
//                                    are its "x,y,w,h;..." bounding_rects;
//                                    keyboard: opened by a shortcut
//   barpop hide
let args = CommandLine.arguments
var delegate: AppDelegate?
var watchdog: DispatchSourceProcess?

switch args.dropFirst().first {
case "daemon" where args.count >= 3:
	guard let parent = pid_t(args[2]), kill(parent, 0) == 0 else { exit(1) }
	let lock = open(NSTemporaryDirectory() + "barpop.lock", O_CREAT | O_RDWR, 0o600)
	guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { exit(0) }
	// Without sketchybar the native menu bar should come back.
	watchdog = DispatchSource.makeProcessSource(identifier: parent, eventMask: .exit, queue: .main)
	watchdog?.setEventHandler { exit(0) }
	watchdog?.resume()
	let app = NSApplication.shared
	delegate = AppDelegate()
	app.delegate = delegate
	app.setActivationPolicy(.accessory)
	app.run()
case "show" where args.count >= 5:
	Messages.post(
		.show, ["popup": args[2], "rects": args[3], "item": args[4], "keyboard": args.count > 5 && args[5] == "keyboard" ? "1" : "0"])
case "hide":
	Messages.post(.hide, [:])
// A reload recreates the bar items; this repaints them from barpop's state.
case "sync":
	Messages.post(.sync, [:])
default:
	FileHandle.standardError.write(Data("usage: barpop daemon <pid> | show <name> <rects> <item> [keyboard] | hide | sync\n".utf8))
	exit(1)
}
