local colors = require("colors")
local settings = require("settings")
local barpop = require("helpers.barpop")

-- barpop's Media model triggers this with TITLE, ARTIST and PLAYING=1/0
-- whenever the now playing track or state changes; no TITLE means nothing.
sbar.add("event", "barpop_media")

local MAX_CHARS = 24

local media = sbar.add("item", "widgets.media", {
	position = "right",
	drawing = false,
	updates = true,
	padding_left = 0,
	padding_right = 0,
	icon = { string = "􀑪", padding_left = 0, font = { size = 12.0 } }, -- music.note
	label = { padding_right = 0, font = { style = settings.font.style_map["Regular"], size = 12 } },
})

local playing = false
local open = false

local function truncate(s, n)
	if (utf8.len(s) or #s) <= n then return s end
	return s:sub(1, utf8.offset(s, n) - 1) .. "…"
end

local function paint()
	local color = open and colors.accent or (playing and colors.white or colors.grey)
	media:set({ icon = { color = color }, label = { color = color } })
end

media:subscribe("barpop_media", function(env)
	local title = env.TITLE or ""
	if title == "" then
		media:set({ drawing = false })
		return
	end
	local artist = env.ARTIST or ""
	playing = env.PLAYING == "1"
	media:set({
		drawing = true,
		icon = { string = playing and "􀑪" or "􀊆" }, -- music.note / pause.fill
		label = { string = truncate(artist ~= "" and title .. " — " .. artist or title, MAX_CHARS) },
	})
	paint()
end)

media:subscribe("mouse.clicked", function(env)
	if env.BUTTON == "right" then
		sbar.exec("PATH=/opt/homebrew/bin:$PATH media-control toggle-play-pause")
	else
		barpop.open(media, "media")
	end
end)

barpop.watch(media, function(is_open)
	open = is_open
	paint()
end)

-- A reload recreates the chip hidden; ask barpop for what is already playing
-- (and the Wi-Fi item's hotspot state). Loaded last, after every barpop event.
sbar.exec("$CONFIG_DIR/helpers/barpop/bin/barpop sync 2>/dev/null")
