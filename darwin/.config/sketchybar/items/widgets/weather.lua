-- ~/.config/sketchybar/items/widgets/weather.lua
local settings = require("settings")

-- === Compact chip (icon + temp) ===
local weather = sbar.add("item", "widgets.weather", {
	position = "right",
	-- Weather symbols run taller than the other icons at the same size.
	icon = { string = "􀇃", padding_left = 0, font = { size = 12.0 } }, -- default cloud.sun
	label = { string = "…°", padding_right = 0, font = { style = settings.font.style_map["Regular"], size = 12 } },
	padding_left = 0,
	padding_right = 0,
	update_freq = 600, -- 10 min
})

-- Cache CoreLocationCLI results: spawning it every refresh is expensive when
-- Location Services is denied (falls back to a multi-second prompt path).
local LOCATION_TTL = 1800
local location_cache = nil
local location_cache_ts = 0

local function get_location(callback)
	if location_cache ~= nil and (os.time() - location_cache_ts) < LOCATION_TTL then
		callback(location_cache)
		return
	end
	sbar.exec("$CONFIG_DIR/helpers/location.sh", function(out)
		location_cache = (out or ""):match("^(%-?[%d%.]+,%-?[%d%.]+)|") or ""
		location_cache_ts = os.time()
		callback(location_cache)
	end)
end

-- wttr.in is flaky; back off exponentially on failure to avoid clogging the
-- lua event loop with 10s curl timeouts (which stalls other items' updates).
local fetch_failures = 0
local next_allowed_ts = 0

local function on_fetch_success()
	fetch_failures = 0
	next_allowed_ts = 0
end

local function on_fetch_failure()
	fetch_failures = math.min(fetch_failures + 1, 6)
	local backoff = math.min(600 * (2 ^ (fetch_failures - 1)), 6 * 3600)
	next_allowed_ts = os.time() + backoff
end

-- === CHIP REFRESH (icon + temp)
local function refresh_chip()
	get_location(function(loc)
		sbar.exec(
			string.format([[curl -s -m 10 'https://wttr.in/%s?format=%%t+%%C&lang=en&u' | tr -d '\n']], loc),
			function(out)
				if not out or out == "" then
					on_fetch_failure()
					return
				end
				local temp, condition = out:match("([%+%-]?%d+°F)%s+(.+)")
				if not temp or not condition then
					on_fetch_failure()
					return
				end
				on_fetch_success()

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

-- === Click behavior ===
-- Left click opens barpop's weather card under the item (see volume.lua).
weather:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		sbar.exec([[open -a "Weather"]]) -- right click opens app
		return
	end
	local rects = {}
	for _, r in pairs(weather:query().bounding_rects or {}) do
		table.insert(rects, string.format("%g,%g,%g,%g", r.origin[1], r.origin[2], r.size[1], r.size[2]))
	end
	if #rects > 0 then
		sbar.exec("$CONFIG_DIR/helpers/barpop/bin/barpop show weather '" .. table.concat(rects, ";") .. "'")
	end
end)

-- === Periodic updates ===
weather:subscribe("routine", function()
	if os.time() < next_allowed_ts then
		return
	end
	refresh_chip()
end)

-- Network state likely changed on wake; clear backoff and refetch.
weather:subscribe("system_woke", function()
	fetch_failures = 0
	next_allowed_ts = 0
	location_cache = nil
	refresh_chip()
end)

-- Initial paint
refresh_chip()
