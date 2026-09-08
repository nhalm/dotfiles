-- Keybindings. https://wiki.hypr.land/Configuring/Binds/
--
-- SUPER is the modifier throughout; SUPER+SHIFT acts on the window rather than
-- the focus. Two collisions in the stock sample are fixed here:
--   * SUPER+P was bound to both the file manager and pseudo -- the file manager
--     is on SUPER+E now.
--   * SUPER+J was togglesplit while SUPER+j is focus-down; togglesplit moved to
--     SUPER+V.

local apps = require("programs")
local mod = "SUPER"

-- --- launching ----------------------------------------------------------
hl.bind(mod .. " + T", hl.dsp.exec_cmd(apps.terminal))
hl.bind(mod .. " + R", hl.dsp.exec_cmd(apps.menu))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(apps.fileManager))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(apps.browser))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd(apps.colorPicker))

-- --- window -------------------------------------------------------------
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + V", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mod .. " + M", hl.dsp.exec_cmd("hyprshutdown"))
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("loginctl lock-session"))

-- --- focus --------------------------------------------------------------
-- h/j/k/l = left/down/up/right. The stock sample had j and l transposed.
local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, dir in pairs(directions) do
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

-- --- resize -------------------------------------------------------------
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -50, y = 0 }), { repeating = true })
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x = 50, y = 0 }), { repeating = true })

-- --- workspaces ---------------------------------------------------------
for i = 1, 10 do
	local key = i % 10 -- 10 lives on the 0 key
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- --- mouse --------------------------------------------------------------
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- --- media and hardware keys --------------------------------------------
-- `locked = true` keeps these working while the session is locked.
local hardware = {
	{ "XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", true },
	{ "XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", true },
	{ "XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", true },
	{ "XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", true },
	{ "XF86MonBrightnessUp", "brightnessctl -e4 -n2 set 5%+", true },
	{ "XF86MonBrightnessDown", "brightnessctl -e4 -n2 set 5%-", true },
	{ "XF86AudioNext", "playerctl next", false },
	{ "XF86AudioPause", "playerctl play-pause", false },
	{ "XF86AudioPlay", "playerctl play-pause", false },
	{ "XF86AudioPrev", "playerctl previous", false },
}

for _, b in ipairs(hardware) do
	hl.bind(b[1], hl.dsp.exec_cmd(b[2]), { locked = true, repeating = b[3] })
end

-- --- screenshots --------------------------------------------------------
-- CleanShot X digits. CTRL+SHIFT rather than SUPER+SHIFT, which is taken by
-- move-to-workspace.
local shots = os.getenv("HOME") .. "/Pictures/Screenshots"

hl.bind("CTRL + SHIFT + 4", hl.dsp.exec_cmd("hyprshot -m region -o " .. shots))
hl.bind("CTRL + SHIFT + 3", hl.dsp.exec_cmd("hyprshot -m output -o " .. shots))
hl.bind("CTRL + SHIFT + 5", hl.dsp.exec_cmd("hyprshot -m window -o " .. shots))
hl.bind(
	"CTRL + SHIFT + 2",
	hl.dsp.exec_cmd("hyprshot -m region --raw | satty --filename - --output-filename " .. shots .. "/annotated-$(date +%s).png")
)
hl.bind("CTRL + SHIFT + 6", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/scripts/screenrec.sh"))

-- --- wallpaper / theme --------------------------------------------------
hl.bind(mod .. " + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/scripts/wallpaper.sh"))

-- --- clipboard ----------------------------------------------------------
hl.bind(
	mod .. " + SHIFT + V",
	hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu --width 80 | cliphist decode | wl-copy")
)

-- --- notifications ------------------------------------------------------
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
