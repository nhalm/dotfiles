local colors = require("colors")
local icons = require("icons")
local settings = require("settings")

-- Padding item required because of bracket
sbar.add("item", { width = 5 })

local apple = sbar.add("item", {
  icon = {
    font = { size = 16.0 },
    string = icons.apple,
    padding_right = 8,
    padding_left = 8,
  },
  label = { drawing = false },
})

sbar.add("bracket", { apple.name }, {
  background = { color = colors.bg1 }
})

-- Padding item required because of bracket
sbar.add("item", { width = 7 })
