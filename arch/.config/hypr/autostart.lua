-- Processes started with the session.
-- https://wiki.hypr.land/Configuring/Basics/Autostart/
--
-- The stock sample autostarts nothing, which is why waybar, notifications and
-- the polkit agent never came up on their own.

hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("swaync")

	-- Ships a systemd user unit rather than a plain binary.
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

	hl.exec_cmd("nm-applet --indicator")

	-- Starts to the tray; the SSH agent needs it running to answer git.
	hl.exec_cmd("1password --silent")
end)
