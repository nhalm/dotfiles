-- Baseline monitor setup.
--
-- Placement is left to Hyprland: position = "auto" packs monitors
-- left-to-right with no gaps, so an unfamiliar display -- hot desk, a client's
-- TV -- works with no rule written for it, and no coordinates are stored that
-- could go stale when a scale changes.
--
-- Pick a variant from monitors/ by writing its name to
-- ~/.config/hypr/monitor-variant (default: scale-125). Anything needing a
-- specific arrangement, such as ordering two identical displays, is layered on
-- top by ~/.config/hypr/monitors.lua, which nwg-displays writes.

local variant = "scale-125"

local f = io.open(os.getenv("HOME") .. "/.config/hypr/monitor-variant", "r")
if f then
	local chosen = f:read("*l")
	f:close()
	if chosen and chosen ~= "" then
		variant = chosen
	end
end

if not pcall(require, "monitors." .. variant) then
	require("monitors.scale-125")
end

hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.25 })
