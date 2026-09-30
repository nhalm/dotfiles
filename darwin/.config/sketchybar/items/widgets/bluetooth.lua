local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local barpop = require("helpers.barpop")

-- barpop triggers this with POWER=on/off as the controller's power changes.
sbar.add("event", "bluetooth_change")

local powered = true
local open = false

local bluetooth = sbar.add("item", "widgets.bluetooth", {
	position = "right",
	padding_left = 0,
	padding_right = 0,
	icon = {
		string = icons.bluetooth.on,
		padding_left = 0,
		padding_right = 0,
		-- SF Pro has no Bluetooth glyph.
		font = { family = "Hack Nerd Font", style = settings.font.style_map["Regular"], size = 14.0 },
	},
	label = { drawing = false },
})

local function paint()
	bluetooth:set({
		icon = {
			string = powered and icons.bluetooth.on or icons.bluetooth.off,
			color = open and colors.accent or (powered and colors.white or colors.grey),
		},
	})
end

local function read_power()
	sbar.exec("system_profiler SPBluetoothDataType | awk '/State:/ { print $2; exit }'", function(out)
		powered = (out or ""):match("On") ~= nil
		paint()
	end)
end

bluetooth:subscribe("bluetooth_change", function(env)
	powered = env.POWER == "on"
	paint()
end)

bluetooth:subscribe("system_woke", read_power)

bluetooth:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		sbar.exec("open 'x-apple.systempreferences:com.apple.BluetoothSettings'")
		return
	end
	barpop.open(bluetooth, "bluetooth")
end)

barpop.watch(bluetooth, function(is_open)
	open = is_open
	paint()
end)

read_power()
