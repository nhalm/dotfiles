-- Processes started with the session.
-- https://wiki.hypr.land/Configuring/Basics/Autostart/
--
-- The stock sample autostarts nothing, which is why the bar, notifications and
-- the polkit agent never came up on their own.

hl.on("hyprland.start", function()
	hl.exec_cmd("swww-daemon")
	hl.exec_cmd(os.getenv("HOME") .. "/.local/scripts/wallpaper.sh --restore")
	hl.exec_cmd("qs -d")
	hl.exec_cmd("swaync")
	hl.exec_cmd("hypridle")

	-- Clipboard history, plus keeping the selection alive after the source
	-- window closes.
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("wl-clip-persist --clipboard regular")

	-- Ships a systemd user unit rather than a plain binary.
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

	-- Network and bluetooth are driven from the tray. Both are plain GTK apps,
	-- so whatever bar is running just needs a tray module.
	hl.exec_cmd("nm-applet --indicator")
	hl.exec_cmd("blueman-applet")

	-- Starts to the tray; the SSH agent needs it running to answer git.
	hl.exec_cmd("1password --silent")
end)
