local settings = require("settings")
local colors = require("colors")

-- Puts the time as far from the edge as the first workspace number on the left.
sbar.add("item", { position = "right", width = 18, padding_left = 0, padding_right = 0 })

local cal = sbar.add("item", {
  icon = {
    color = colors.white,
    padding_left = 0,
    font = {
      style = settings.font.style_map["Regular"],
      size = 12.0,
    },
  },
  label = {
    color = colors.white,
    padding_right = 0,
    width = 49,
    align = "right",
    font = { family = settings.font.numbers },
  },
  position = "right",
  padding_left = 0,
  padding_right = 0,
  update_freq = 30,
  click_script = "open -a 'Calendar'"
})

sbar.add("bracket", { cal.name }, {
  background = { drawing = false }
})

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  cal:set({ icon = os.date("%a. %d %b."), label = os.date("%H:%M") })
end)
