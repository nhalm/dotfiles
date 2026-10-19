local icons = require("icons")
local colors = require("colors")
local settings = require("settings")
local barpop = require("helpers.barpop")

local battery = sbar.add("item", "widgets.battery", {
  position = "right",
  padding_left = 0,
  padding_right = 0,
  icon = {
    padding_left = 0,
    padding_right = 0,
    font = {
      style = settings.font.style_map["Regular"],
      size = 15.0,
    }
  },
  label = { drawing = false },
  update_freq = 180,
})

local color = colors.white
local open = false

local function paint()
  battery:set({ icon = { color = open and colors.accent or color } })
end

battery:subscribe({"routine", "power_source_change", "system_woke"}, function()
  sbar.exec("pmset -g batt", function(batt_info)
    local icon = "!"
    local found, _, charge = batt_info:find("(%d+)%%")
    if found then charge = tonumber(charge) end

    color = colors.white
    if batt_info:find("AC Power") then
      icon = icons.battery.charging
    elseif found and charge > 80 then
      icon = icons.battery._100
    elseif found and charge > 60 then
      icon = icons.battery._75
    elseif found and charge > 40 then
      icon = icons.battery._50
    elseif found and charge > 20 then
      icon = icons.battery._25
    else
      icon = icons.battery._0
      color = colors.red
    end

    battery:set({ icon = { string = icon } })
    paint()
  end)
end)

battery:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec("open 'x-apple.systempreferences:com.apple.Battery-Settings.extension'")
    return
  end
  barpop.open(battery, "battery")
end)

barpop.watch(battery, function(is_open)
  open = is_open
  paint()
end)
