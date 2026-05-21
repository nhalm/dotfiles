-- AeroSpace workspace chips for SketchyBar.
--
-- Design follows the canonical FelixKratz pattern (SketchyBar discussion #599
-- and SbarLua example/items/spaces.lua):
--   * Items are created once at startup; nothing is ever recreated.
--   * A single observer runs ONE bulk refresh per event, updating every item
--     in one pass. Per-item subscriptions + per-workspace exec calls have
--     historically deadlocked sketchybar via SbarLua issue #794 (mach port
--     queue saturation when many :set() calls dispatch concurrently).
--   * No polling loop.
--   * No item:query() — visibility / pinning are tracked in Lua.

local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

sbar.add("event", "aerospace_workspace_change")

local STYLE = {
	chip_bg = colors.bg1,
	chip_border = colors.black,
	chip_height = 26,
	bracket_border = colors.bg2,
	active_bracket_border = colors.grey,
	active_icon_highlight = colors.red,
	active_label_highlight = colors.white,
	inactive_icon_color = colors.white,
	inactive_label_color = colors.grey,
}

local function read_sync(cmd)
	local f = io.popen(cmd)
	local out = (f and f:read("*a")) or ""
	if f then
		f:close()
	end
	return out
end

local function lines(s)
	local r = {}
	for line in s:gmatch("[^\r\n]+") do
		r[#r + 1] = line
	end
	return r
end

local workspaces = lines(read_sync("aerospace list-workspaces --all 2>/dev/null"))

local items = {}
local brackets = {}
local pinned_display = {}

for _, ws in ipairs(workspaces) do
	local item = sbar.add("item", "aws." .. ws, {
		position = "left",
		display = "active",
		icon = {
			font = { family = settings.font.numbers },
			string = ws,
			padding_left = 15,
			padding_right = 8,
			color = STYLE.inactive_icon_color,
			highlight_color = STYLE.active_icon_highlight,
		},
		label = {
			padding_right = 20,
			color = STYLE.inactive_label_color,
			highlight_color = STYLE.active_label_highlight,
			font = "sketchybar-app-font:Regular:16.0",
			y_offset = -1,
			string = " —",
		},
		padding_left = 1,
		padding_right = 1,
		background = {
			color = STYLE.chip_bg,
			border_width = 1,
			height = STYLE.chip_height,
			border_color = STYLE.chip_border,
		},
		click_script = "aerospace workspace " .. ws,
	})

	local bracket = sbar.add("bracket", "aws.bracket." .. ws, { item.name }, {
		background = {
			color = colors.transparent,
			border_color = STYLE.bracket_border,
			height = STYLE.chip_height + 2,
			border_width = 2,
		},
	})

	item:subscribe("mouse.clicked", function(env)
		if env.BUTTON == "right" then
			sbar.exec("aerospace move-node-to-workspace " .. ws)
		end
	end)

	items[ws] = item
	brackets[ws] = bracket
	pinned_display[ws] = "active"
end

sbar.add("item", { position = "left", width = settings.group_paddings })

-- Two bulk exec calls per refresh:
--   1) list-workspaces gives us monitor-id + focused/visible flags for every
--      workspace (including empty ones).
--   2) list-windows gives us the app icons. Empty workspaces don't appear
--      here, which is why (1) is needed too.
-- Nested so we have a single coherent snapshot when we paint.
local function refresh()
	sbar.exec(
		[[aerospace list-workspaces --all --format '%{workspace}	%{monitor-id}	%{workspace-is-focused}	%{workspace-is-visible}' 2>/dev/null]],
		function(ws_out)
			local meta = {}
			for line in (ws_out or ""):gmatch("[^\r\n]+") do
				local ws, mon, focused, visible = line:match("^(%S+)\t(%S+)\t(%S+)\t(%S+)$")
				if ws then
					meta[ws] = {
						display = tonumber(mon) or 1,
						focused = focused == "true",
						visible = visible == "true",
					}
				end
			end

			sbar.exec(
				[[aerospace list-windows --all --format '%{workspace}	%{app-name}' 2>/dev/null]],
				function(win_out)
					local apps_by_ws = {}
					for line in (win_out or ""):gmatch("[^\r\n]+") do
						local ws, app = line:match("^(%S+)\t(.+)$")
						if ws and app then
							local bucket = apps_by_ws[ws]
							if not bucket then
								bucket = { seen = {}, list = {} }
								apps_by_ws[ws] = bucket
							end
							app = app:gsub("^%s+", ""):gsub("%s+$", "")
							if app ~= "" and not bucket.seen[app] then
								bucket.seen[app] = true
								bucket.list[#bucket.list + 1] = app
							end
						end
					end

					for ws, item in pairs(items) do
						local m = meta[ws] or { display = 1, focused = false, visible = false }
						local bucket = apps_by_ws[ws]
						local apps = bucket and bucket.list or {}
						local icons_str = ""
						for _, app in ipairs(apps) do
							icons_str = icons_str .. (app_icons[app] or app_icons["Default"] or "·")
						end

						local selected = m.focused
						local has_apps = #apps > 0
						local show = m.visible or has_apps
						if icons_str == "" then
							icons_str = " —"
						end

						-- Only re-set display when it actually changed; sketchybar
						-- treats display changes as expensive layout events.
						if pinned_display[ws] ~= m.display then
							pinned_display[ws] = m.display
							item:set({ display = m.display })
							brackets[ws]:set({ display = m.display })
						end

						local drawing = show and "on" or "off"
						item:set({
							drawing = drawing,
							icon = { highlight = selected },
							label = { string = icons_str, highlight = selected },
							background = {
								border_color = selected and STYLE.active_bracket_border
									or STYLE.chip_border,
							},
						})
						brackets[ws]:set({
							drawing = drawing,
							background = {
								border_color = selected and STYLE.active_bracket_border
									or STYLE.bracket_border,
							},
						})
					end
				end
			)
		end
	)
end

local observer = sbar.add("item", "aws.observer", { drawing = "off", updates = true })

observer:subscribe("aerospace_workspace_change", refresh)
observer:subscribe("front_app_switched", refresh)
observer:subscribe("display_change", refresh)
observer:subscribe("system_woke", refresh)

refresh()
