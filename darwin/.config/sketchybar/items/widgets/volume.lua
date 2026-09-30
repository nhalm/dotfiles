local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local barpop = require("helpers.barpop")

-- Hidden, but it carries the volume_change subscription, so it must update
-- while not drawn.
local volume_percent = sbar.add("item", "widgets.volume1", {
  position = "right",
  drawing = false,
  updates = true,
  padding_left = 0,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    string = "??%",
    padding_left = 0,
    padding_right = 0,
    font = { family = settings.font.numbers }
  },
})

local volume_icon = sbar.add("item", "widgets.volume2", {
  position = "right",
  padding_left = 0,
  padding_right = 0,
  icon = {
    string = icons.volume._100,
    padding_left = 0,
    padding_right = 0,
    width = 0,
    align = "left",
    color = colors.grey,
    font = {
      style = settings.font.style_map["Regular"],
      size = 14.0,
    },
  },
  label = {
    width = 20,
    align = "left",
    padding_left = 0,
    padding_right = 0,
    font = {
      style = settings.font.style_map["Regular"],
      size = 14.0,
    },
  },
})

local function show_volume(volume)
  local icon = icons.volume._0
  if volume > 60 then
    icon = icons.volume._100
  elseif volume > 30 then
    icon = icons.volume._66
  elseif volume > 10 then
    icon = icons.volume._33
  elseif volume > 0 then
    icon = icons.volume._10
  end

  local lead = ""
  if volume < 10 then
    lead = "0"
  end

  volume_icon:set({ label = icon })
  volume_percent:set({ label = lead .. volume .. "%" })
end

volume_percent:subscribe("volume_change", function(env)
  show_volume(tonumber(env.INFO))
end)

-- volume_change only fires on a change, so read the starting level once.
sbar.exec("osascript -e 'output volume of (get volume settings)'", function(out)
  local volume = tonumber(out)
  if volume then show_volume(volume) end
end)

local function volume_click(env)
  if env.BUTTON == "right" then
    sbar.exec("open /System/Library/PreferencePanes/Sound.prefpane")
    return
  end
  barpop.open(volume_icon, "volume")
end

local function volume_scroll(env)
  local delta = env.INFO.delta
  if not (env.INFO.modifier == "ctrl") then delta = delta * 10.0 end

  sbar.exec('osascript -e "set volume output volume (output volume of (get volume settings) + ' .. delta .. ')"')
end

barpop.watch(volume_icon, function(open)
  volume_icon:set({ label = { color = open and colors.accent or colors.white } })
end)

volume_icon:subscribe("mouse.clicked", volume_click)
volume_icon:subscribe("mouse.scrolled", volume_scroll)

