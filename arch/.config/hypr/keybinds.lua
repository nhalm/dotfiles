-- Keybindings. https://wiki.hypr.land/Configuring/Binds/
--
-- SUPER is the modifier throughout; SUPER+SHIFT acts on the window rather than
-- the focus. Two collisions in the stock sample are fixed here:
--   * SUPER+P was bound to both the file manager and pseudo -- the file manager
--     is on SUPER+E now.
--   * SUPER+J was togglesplit while SUPER+j is focus-down; the scrolling layout
--     has no split to toggle, so SUPER+V consumes/expels instead.
--
-- Every bind carries a `description` of the form "Category: what it does".
-- `hyprctl binds -j` reports nothing but `__lua` for a Lua dispatcher, so the
-- description is the only thing the SUPER+slash overlay has to read. Keep the
-- prefix -- the overlay groups on it.

local apps = require("programs")
local mod = "SUPER"

local function desc(text)
	return { description = text }
end

-- --- launching ----------------------------------------------------------
hl.bind(mod .. " + T", hl.dsp.exec_cmd(apps.terminal), desc("Launch: terminal"))
hl.bind(mod .. " + R", hl.dsp.exec_cmd(apps.menu), desc("Launch: app launcher"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(apps.fileManager), desc("Launch: file manager"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(apps.browser), desc("Launch: browser"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd(apps.colorPicker), desc("Launch: colour picker"))

-- --- window -------------------------------------------------------------
hl.bind(mod .. " + C", hl.dsp.window.close(), desc("Window: close"))
hl.bind(mod .. " + F", hl.dsp.window.float({ action = "toggle" }), desc("Window: toggle floating"))
hl.bind(mod .. " + M", hl.dsp.exec_cmd("hyprshutdown"), desc("System: shutdown menu"))
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("loginctl lock-session"), desc("System: lock session"))

-- --- focus --------------------------------------------------------------
-- h/j/k/l = left/down/up/right. The stock sample had j and l transposed.
-- Under scrolling, left/right crosses columns and up/down moves within one.
-- These stay on hl.dsp.focus rather than the layout's own `focus` message,
-- which wraps at the ends instead of moving to the neighbouring monitor.
-- Ordered, not a keyed table -- `pairs` iteration order is undefined and the
-- SUPER+slash overlay lists binds in declaration order.
local directions = {
	{ "h", "left" },
	{ "j", "down" },
	{ "k", "up" },
	{ "l", "right" },
}

for _, d in ipairs(directions) do
	local key, dir = d[1], d[2]
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }), desc("Focus: " .. dir))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }), desc("Window: move " .. dir))
end

-- --- scrolling layout ---------------------------------------------------
-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
hl.bind(mod .. " + minus", hl.dsp.layout("colresize -conf"), desc("Layout: narrower column"))
hl.bind(mod .. " + equal", hl.dsp.layout("colresize +conf"), desc("Layout: wider column"))
hl.bind(mod .. " + comma", hl.dsp.layout("move -col"), desc("Layout: scroll tape left"))
hl.bind(mod .. " + period", hl.dsp.layout("move +col"), desc("Layout: scroll tape right"))
hl.bind(mod .. " + SHIFT + comma", hl.dsp.layout("swapcol l"), desc("Layout: swap column left"))
hl.bind(mod .. " + SHIFT + period", hl.dsp.layout("swapcol r"), desc("Layout: swap column right"))
hl.bind(mod .. " + P", hl.dsp.layout("promote"), desc("Layout: window to its own column"))
hl.bind(mod .. " + V", hl.dsp.layout("consume_or_expel next"), desc("Layout: consume/expel window"))
hl.bind(mod .. " + G", hl.dsp.layout("center"), desc("Layout: centre column"))
hl.bind(mod .. " + CTRL + equal", hl.dsp.layout("fit expand"), desc("Layout: expand into free space"))
hl.bind(mod .. " + CTRL + minus", hl.dsp.layout("fit visible"), desc("Layout: fit visible columns"))

-- --- workspaces ---------------------------------------------------------
for i = 1, 10 do
	local key = i % 10 -- 10 lives on the 0 key
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }), desc("Workspace: go to " .. i))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), desc("Workspace: move window to " .. i))
end

hl.bind(mod .. " + Tab", hl.dsp.exec_cmd("qs ipc call overview toggle"), desc("Workspace: overview"))
hl.bind(mod .. " + grave", hl.dsp.focus({ workspace = "previous" }), desc("Workspace: previous"))
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"), desc("Workspace: toggle scratchpad"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), desc("Workspace: window to scratchpad"))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), desc("Workspace: next"))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), desc("Workspace: previous"))

-- --- mouse --------------------------------------------------------------
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: drag" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: resize" })

-- --- media and hardware keys --------------------------------------------
-- `locked = true` keeps these working while the session is locked.
local hardware = {
	{ "XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", true, "volume up" },
	{ "XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", true, "volume down" },
	{ "XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", true, "mute output" },
	{ "XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", true, "mute microphone" },
	{ "XF86MonBrightnessUp", "brightnessctl -e4 -n2 set 5%+", true, "brightness up" },
	{ "XF86MonBrightnessDown", "brightnessctl -e4 -n2 set 5%-", true, "brightness down" },
	{ "XF86AudioNext", "playerctl next", false, "next track" },
	{ "XF86AudioPause", "playerctl play-pause", false, "play/pause" },
	{ "XF86AudioPlay", "playerctl play-pause", false, "play/pause" },
	{ "XF86AudioPrev", "playerctl previous", false, "previous track" },
}

for _, b in ipairs(hardware) do
	hl.bind(b[1], hl.dsp.exec_cmd(b[2]), {
		locked = true,
		repeating = b[3],
		description = "Media: " .. b[4],
	})
end

-- --- screenshots --------------------------------------------------------
-- CleanShot X digits. CTRL+SHIFT rather than SUPER+SHIFT, which is taken by
-- move-to-workspace.
local shots = os.getenv("HOME") .. "/Pictures/Screenshots"

hl.bind("CTRL + SHIFT + 4", hl.dsp.exec_cmd("hyprshot -m region -o " .. shots), desc("Screenshot: region"))
hl.bind("CTRL + SHIFT + 3", hl.dsp.exec_cmd("hyprshot -m output -o " .. shots), desc("Screenshot: whole output"))
hl.bind("CTRL + SHIFT + 5", hl.dsp.exec_cmd("hyprshot -m window -o " .. shots), desc("Screenshot: window"))
hl.bind(
	"CTRL + SHIFT + 2",
	hl.dsp.exec_cmd("hyprshot -m region --raw | satty --filename - --output-filename " .. shots .. "/annotated-$(date +%s).png"),
	desc("Screenshot: region, annotate")
)
hl.bind("CTRL + SHIFT + 6", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/scripts/screenrec.sh"), desc("Screenshot: record region"))

-- --- wallpaper / theme --------------------------------------------------
hl.bind(mod .. " + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"), desc("Theme: wallpaper picker"))
hl.bind(mod .. " + CTRL + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/scripts/wallpaper.sh --random"), desc("Theme: random wallpaper"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/scripts/theme-mode.sh"), desc("Theme: light/dark toggle"))

-- --- clipboard ----------------------------------------------------------
hl.bind(
	mod .. " + SHIFT + V",
	hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu --width 80 | cliphist decode | wl-copy"),
	desc("System: clipboard history")
)

-- --- notifications ------------------------------------------------------
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"), desc("System: notification centre"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("qs ipc call sidebar toggle"), desc("System: quick settings"))
hl.bind(mod .. " + slash", hl.dsp.exec_cmd("qs ipc call hotkeys toggle"), desc("System: this overlay"))
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/scripts/toggle-float.sh"), desc("Window: float all on workspace"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("pkill hyprsunset || hyprsunset -t 4000"), desc("Theme: blue light filter"))
