local icons = require("icons")
local colors = require("colors")
local barpop = require("helpers.barpop")

local performance = sbar.add("item", "widgets.performance", {
	position = "right",
	padding_left = 0,
	padding_right = 0,
	icon = { string = icons.cpu, padding_left = 0, padding_right = 0 },
	label = { drawing = false },
})

barpop.watch(performance, function(open)
	performance:set({ icon = { color = open and colors.accent or colors.white } })
end)

performance:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		sbar.exec("open -a 'Activity Monitor'")
		return
	end
	barpop.open(performance, "performance")
end)
