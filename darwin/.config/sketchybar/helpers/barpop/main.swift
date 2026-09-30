import AppKit

// barpop draws sketchybar's richer popups in its own panel, and keeps the
// native menu bar from showing over the bar.
//   barpop daemon                    run the app (sketchybar starts it)
//   barpop show <name> <x> <width>   open a popup under the item at x
//   barpop hide
let args = CommandLine.arguments

switch args.dropFirst().first {
case "daemon":
	let app = NSApplication.shared
	let delegate = AppDelegate()
	app.delegate = delegate
	app.setActivationPolicy(.accessory)
	app.run()
case "show" where args.count >= 5:
	Messages.post(.show, ["popup": args[2], "x": args[3], "width": args[4]])
case "hide":
	Messages.post(.hide, [:])
default:
	FileHandle.standardError.write("usage: barpop daemon | show <name> <x> <width> | hide\n".data(using: .utf8)!)
	exit(1)
}
