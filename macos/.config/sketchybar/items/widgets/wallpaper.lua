local icons = require("icons")
local colors = require("colors")
local barpop = require("helpers.barpop")

local wallpaper = sbar.add("item", "widgets.wallpaper", {
	position = "right",
	padding_left = 0,
	padding_right = 0,
	icon = { string = icons.wallpaper, padding_left = 0, padding_right = 0 },
	label = { drawing = false },
})

-- caps+w in aerospace.toml.
barpop.shortcut(wallpaper, "wallpaper")

barpop.watch(wallpaper, function(open)
	wallpaper:set({ icon = { color = open and colors.accent or colors.white } })
end)

wallpaper:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		sbar.exec("open ~/.local/share/wallpapers")
		return
	end
	barpop.open(wallpaper, "wallpaper")
end)
