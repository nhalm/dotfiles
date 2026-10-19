-- Processes started with the session.
-- https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	-- wallpaper.sh starts the daemon itself, resolving awww-daemon or
	-- swww-daemon; the AUR package installs the former.
	hl.exec_cmd(os.getenv("HOME") .. "/.local/scripts/wallpaper.sh --restore")
	hl.exec_cmd("qs -d")
	hl.exec_cmd("swaync")
	hl.exec_cmd("hypridle")
	hl.exec_cmd(os.getenv("HOME") .. "/.local/scripts/low-battery-notify.sh")

	-- Clipboard history, plus keeping the selection alive after the source
	-- window closes.
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("wl-clip-persist --clipboard regular")

	-- Ships a systemd user unit rather than a plain binary.
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

	-- The pairing agent BlueZ needs to confirm a new device; setup hides its
	-- tray icon.
	hl.exec_cmd("blueman-applet")

	-- Starts to the tray.
	hl.exec_cmd("1password --silent")
end)
