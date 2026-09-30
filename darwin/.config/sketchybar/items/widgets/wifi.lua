local icons = require("icons")
local colors = require("colors")
local barpop = require("helpers.barpop")

local wifi = sbar.add("item", "widgets.wifi.padding", {
	position = "right",
	padding_left = 0,
	padding_right = 0,
	icon = { padding_left = 0, padding_right = 0 },
	label = { drawing = false },
})

local connected = false
local open = false

local function paint()
	wifi:set({
		icon = {
			string = connected and icons.wifi.connected or icons.wifi.disconnected,
			color = open and colors.accent or (connected and colors.white or colors.red),
		},
	})
end

wifi:subscribe({ "wifi_change", "system_woke" }, function()
	sbar.exec("ipconfig getifaddr en0", function(ip)
		connected = ip ~= ""
		paint()
	end)
end)

barpop.watch(wifi, function(is_open)
	open = is_open
	paint()
end)

wifi:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		sbar.exec("open 'x-apple.systempreferences:com.apple.wifi-settings-extension'")
		return
	end
	barpop.open(wifi, "wifi")
end)
