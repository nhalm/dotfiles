local icons = require("icons")
local colors = require("colors")
local barpop = require("helpers.barpop")

-- barpop's Wifi model triggers this with HOTSPOT=1/0, DEVICE and VIA whenever the
-- Mac joins or leaves an iPhone's Personal Hotspot; media.lua's
-- `barpop sync` repeats it after a reload.
sbar.add("event", "barpop_network")

local wifi = sbar.add("item", "widgets.wifi.padding", {
	position = "right",
	padding_left = 0,
	padding_right = 0,
	icon = { padding_left = 0, padding_right = 0 },
	label = { drawing = false },
})

local connected = false
local hotspot = false
local open = false

local function paint()
	wifi:set({
		icon = {
			string = hotspot and icons.wifi.hotspot or (connected and icons.wifi.connected or icons.wifi.disconnected),
			color = open and colors.accent or ((connected or hotspot) and colors.white or colors.red),
		},
	})
end

wifi:subscribe({ "wifi_change", "system_woke" }, function()
	-- Associated, not an IPv4 address: IPv6-only networks (a hotspot on an
	-- IPv6-only carrier) have none for getifaddr.
	sbar.exec("ipconfig getsummary en0 | grep -c '^  SSID : '", function(n)
		connected = tonumber(n) ~= nil and tonumber(n) > 0
		paint()
	end)
end)

wifi:subscribe("barpop_network", function(env)
	hotspot = env.HOTSPOT == "1"
	paint()
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
