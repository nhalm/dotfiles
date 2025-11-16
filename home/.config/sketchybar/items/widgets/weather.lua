-- ~/.config/sketchybar/items/widgets/weather.lua
local colors = require("colors")
local settings = require("settings")

-- === Compact chip (icon + temp) ===
local weather = sbar.add("item", "widgets.weather", {
	position = "right",
	icon = { string = "􀇃" }, -- default cloud.sun
	label = { string = "…°", font = { style = settings.font.style_map["Bold"], size = 12 } },
	padding_left = 6,
	padding_right = 6,
	update_freq = 600, -- 10 min
})

-- === Popup bracket container ===
local weather_bracket = sbar.add("bracket", "widgets.weather.bracket", { weather.name }, {
	background = { color = colors.bg1 },
	popup = { align = "center", height = 35 },
})

-- Helper: add a popup row with fixed left/right columns
local function add_row(name, left, right, total_w, left_w, right_w)
	total_w = total_w or 260
	left_w = left_w or 120
	right_w = right_w or 140
	return sbar.add("item", name, {
		position = "popup." .. weather_bracket.name,
		icon = { string = left, align = "left", width = left_w },
		label = { string = right, align = "right", width = right_w },
		width = total_w,
		padding_left = 6,
		padding_right = 6,
		background = { color = colors.bg2 },
	})
end

-- Header widths chosen so they never collide
local header = sbar.add("item", "widgets.weather.row.header", {
	position = "popup." .. weather_bracket.name,
	icon = { align = "left", width = 170, string = "—" },
	label = { align = "right", width = 80, string = "—", max_chars = 6 },
	width = 250,
	padding_left = 6,
	padding_right = 6,
	background = { color = colors.bg2 },
})

local cond = sbar.add("item", "widgets.weather.row.cond", {
	position = "popup." .. weather_bracket.name,
	icon = { string = "Conditions", align = "left", width = 120 },
	label = { string = "—", align = "right", width = 140 },
	width = 260,
	padding_left = 6,
	padding_right = 6,
	background = { color = colors.bg2 },
})

local feels = add_row("widgets.weather.row.feels", "Feels like", "—")
local humidity = add_row("widgets.weather.row.hum", "Humidity", "—")
local wind = add_row("widgets.weather.row.wind", "Wind", "—")

local h1 = add_row("widgets.weather.row.h1", "Next 1h", "—")
local h3 = add_row("widgets.weather.row.h3", "Next 3h", "—")
local h6 = add_row("widgets.weather.row.h6", "Next 6h", "—")

-- Get location from CoreLocationCLI, fallback to auto-detect
local function get_location(callback)
	sbar.exec(
		[[CoreLocationCLI -format "%latitude,%longitude" 2>/dev/null | tr ' ' ',' | tr -d '\n' || echo ""]],
		function(out)
			print("[WEATHER DEBUG] CoreLocationCLI output: '" .. tostring(out) .. "'")
			if out and out ~= "" and out:match("^%-?[%d%.]+,%-?[%d%.]+$") then
				print("[WEATHER DEBUG] Using coordinates: " .. out)
				callback(out)
			else
				print("[WEATHER DEBUG] Falling back to IP detection")
				callback("")
			end
		end
	)
end

-- === CHIP REFRESH (icon + temp)
local function refresh_chip()
	get_location(function(loc)
		sbar.exec(
			string.format([[curl -s 'https://wttr.in/%s?format=%%t+%%C&lang=en&u' | tr -d '\n']], loc),
			function(out)
				if not out or out == "" then
					return
				end
				local temp, condition = out:match("([%+%-]?%d+°F)%s+(.+)")
				if not temp or not condition then
					return
				end

				local c = condition:lower()
				local icon = "􀇃" -- cloud.sun
				if c:find("storm") or c:find("thunder") then
					icon = "􀇏" -- cloud.bolt.rain
				elseif c:find("rain") or c:find("drizzle") then
					icon = "􀇈" -- cloud.rain
				elseif c:find("snow") or c:find("sleet") or c:find("hail") then
					icon = "􀇇" -- cloud.snow
				elseif c:find("clear") or c:find("sun") then
					icon = "􀆮" -- sun.max
				elseif c:find("cloud") or c:find("overcast") then
					icon = "􀇂" -- cloud
				end

				weather:set({ icon = { string = icon }, label = { string = temp } })
			end
		)
	end)
end

-- === POPUP REFRESH (details) — harden PATH for jq when launched by services
local function refresh_popup()
	get_location(function(loc)
		print("[WEATHER DEBUG] Location for popup: '" .. loc .. "'")
		local url = string.format("https://wttr.in/%s?format=j1&lang=en&u", loc)
		print("[WEATHER DEBUG] Fetching URL: " .. url)
		local cmd = [[/bin/bash -lc '
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
    curl -fsSL "]] .. url .. [[" | jq -r "
      def h(i): .weather[0].hourly[i] | \"\\(.tempF)°F, \\(.weatherDesc[0].value)\";
      [
        (.nearest_area[0].areaName[0].value + \", \" + .nearest_area[0].region[0].value), # city, state
        .current_condition[0].temp_F,               # tempF (no unit)
        .current_condition[0].weatherDesc[0].value, # condition
        .current_condition[0].FeelsLikeF,           # feels
        .current_condition[0].humidity,             # humidity
        (.current_condition[0].windspeedMiles|tostring + \" mph\"), # wind
        h(1), h(3), h(6)
      ] | .[]
    "
  ']]

		sbar.exec(cmd, function(out)
			if not out or out == "" then
				return
			end
			local lines = {}
			for line in string.gmatch(out, "[^\r\n]+") do
				lines[#lines + 1] = line
			end
			if #lines < 9 then
				return
			end -- expect 9 fields

			local location, tempF, desc, feelF, humP, windStr, n1, n3, n6 =
				lines[1], lines[2], lines[3], lines[4], lines[5], lines[6], lines[7], lines[8], lines[9]

			header:set({
				icon = { string = location },
				label = { string = tostring(tempF) .. "°F" },
			})
			cond:set({ label = { string = desc } })

			feels:set({ label = { string = tostring(feelF) .. "°F" } })
			humidity:set({ label = { string = tostring(humP) .. "%" } })
			wind:set({ label = { string = windStr } })
			h1:set({ label = { string = n1 } })
			h3:set({ label = { string = n3 } })
			h6:set({ label = { string = n6 } })
		end)
	end)
end

local function hide_popup()
	sbar.set("widgets.weather.bracket", { popup = { drawing = "off" } })
end

-- === Click behavior ===
weather:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		sbar.exec([[open -a "Weather"]]) -- right click opens app
	else
		sbar.set("widgets.weather.bracket", { popup = { drawing = "toggle" } })
		sbar.delay(0.05, function()
			if sbar.query("widgets.weather.bracket").popup.drawing == "on" then
				refresh_popup()
			end
		end)
	end
end)

weather:subscribe("mouse.exited.global", hide_popup)
weather_bracket:subscribe("mouse.exited.global", hide_popup)
header:subscribe("mouse.exited.global", hide_popup)
cond:subscribe("mouse.exited.global", hide_popup)
feels:subscribe("mouse.exited.global", hide_popup)
humidity:subscribe("mouse.exited.global", hide_popup)
wind:subscribe("mouse.exited.global", hide_popup)
h1:subscribe("mouse.exited.global", hide_popup)
h3:subscribe("mouse.exited.global", hide_popup)
h6:subscribe("mouse.exited.global", hide_popup)

-- === Periodic updates ===
weather:subscribe({ "routine", "system_woke" }, function()
	refresh_chip()
	sbar.delay(300, refresh_popup) -- soft refresh even if popup closed
end)

-- Spacing after widget
sbar.add("item", { position = "right", width = settings.group_paddings })

-- Initial paint
refresh_chip()
