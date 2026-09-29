local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

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
  popup = { align = "center" }
})

local charge_row = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = "Charge:",
    width = 100,
    align = "left"
  },
  label = {
    string = "??%",
    width = 100,
    align = "right"
  },
})

local remaining_time = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = "Time remaining:",
    width = 100,
    align = "left"
  },
  label = {
    string = "??:??h",
    width = 100,
    align = "right"
  },
})


battery:subscribe({"routine", "power_source_change", "system_woke"}, function()
  sbar.exec("pmset -g batt", function(batt_info)
    local icon = "!"
    local label = "?"

    local found, _, charge = batt_info:find("(%d+)%%")
    if found then
      charge = tonumber(charge)
      label = charge .. "%"
    end

    local color = colors.white
    local charging, _, _ = batt_info:find("AC Power")

    if charging then
      icon = icons.battery.charging
    else
      if found and charge > 80 then
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
    end

    battery:set({
      icon = {
        string = icon,
        color = color
      },
    })
    charge_row:set({ label = label })
  end)
end)

require("helpers.close_on_leave")({ battery, charge_row, remaining_time }, function()
  battery:set({ popup = { drawing = false } })
end)

battery:subscribe("mouse.clicked", function(env)
  local drawing = battery:query().popup.drawing
  battery:set( { popup = { drawing = "toggle" } })

  if drawing == "off" then
    sbar.exec("pmset -g batt", function(batt_info)
      local found, _, remaining = batt_info:find(" (%d+:%d+) remaining")
      local label = found and remaining .. "h" or "No estimate"
      remaining_time:set( { label = label })
    end)
  end
end)

sbar.add("bracket", "widgets.battery.bracket", { battery.name }, {
  background = { drawing = false }
})

