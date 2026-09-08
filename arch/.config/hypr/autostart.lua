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
	hl.exec_cmd(os.getenv("HOME") .. "/.local/scripts/low-battery-notify.sh")

	-- Clipboard history, plus keeping the selection alive after the source
	-- window closes.
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("wl-clip-persist --clipboard regular")

	-- Ships a systemd user unit rather than a plain binary.
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

	-- Network and bluetooth are driven from the sidebar, not tray applets, but
	-- blueman-applet still has to run: it provides the pairing agent that answers
	-- BlueZ's confirmation prompts. Without it, pairing a new device fails with
	-- AuthenticationFailed. Its tray icon is disabled via
	-- `gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"`.
	hl.exec_cmd("blueman-applet")

	-- Starts to the tray; the SSH agent needs it running to answer git.
	hl.exec_cmd("1password --silent")
end)
