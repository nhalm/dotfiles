-- Fallback monitor setup, used until a machine-local layout exists.
--
-- The real layout is not kept in this repo: it is machine-specific, and these
-- two externals are identical models (Lenovo P27u-20) that differ only by
-- serial, so connector names like DP-1/DP-2 can swap between boots.
--
-- Arrange displays interactively with `nwg-displays`, which writes
-- ~/.config/hypr/monitors.lua -- an unstowed, untracked file that hyprland.lua
-- loads after this one, overriding it. Tick "use monitor descriptions" in its
-- UI so rules match on serial rather than connector.

-- Catch-all, so an unknown display still comes up.
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- Built-in panel. 1.5x is the readable scale on this one.
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = "1.5",
})
