-- AeroSpace workspaces for SketchyBar: each number with its apps' glyphs,
-- spaced apart like the items on the right. The focused one lights in the
-- accent, as a bar item does while its popup is open.
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
	focused_color = colors.accent,
	active_app_color = colors.white,
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

-- aerospace launches sketchybar from after-startup-command, before its own
-- server answers, so a single query returns nothing and no chips get built.
local function query_workspaces()
	for _ = 1, 20 do
		local w = lines(read_sync("aerospace list-workspaces --all 2>/dev/null"))
		if #w > 0 then
			return w
		end
		os.execute("sleep 0.25")
	end
	return {}
end

local workspaces = query_workspaces()

local items = {}
local slots = {}
local parts = {}
local pinned_display = {}

-- Each app glyph gets its own fixed-width slot, since the glyphs' own widths vary.
-- A glyph is about 16px, so a slot leaves about 3px each side; GAP is the space
-- between the number and its glyphs, SPACING the space between workspaces
-- (the right side's gap between items).
local MAX_APPS = 6
local SLOT_WIDTH = 22
local SLOT_SLACK = 3
local GAP = 6
local SPACING = 16

-- Puts the first number as far from the edge as the calendar's text on the right.
sbar.add("item", { position = "left", width = 18, padding_left = 0, padding_right = 0 })

for _, ws in ipairs(workspaces) do
	local click = "aerospace workspace " .. ws
	local item = sbar.add("item", "aws." .. ws, {
		position = "left",
		display = "active",
		padding_left = 0,
		padding_right = 0,
		icon = {
			font = { family = settings.font.numbers },
			string = ws,
			padding_left = 0,
			padding_right = GAP - SLOT_SLACK,
			color = STYLE.inactive_icon_color,
		},
		label = { drawing = false },
		click_script = click,
	})
	local ws_parts = { item }

	slots[ws] = {}
	for k = 1, MAX_APPS do
		local slot = sbar.add("item", "aws.app." .. ws .. "." .. k, {
			position = "left",
			display = "active",
			drawing = k == 1,
			padding_left = 0,
			padding_right = 0,
			width = SLOT_WIDTH,
			icon = { drawing = false },
			label = {
				font = "sketchybar-app-font:Regular:16.0",
				y_offset = -1,
				width = SLOT_WIDTH,
				align = "center",
				padding_left = 0,
				padding_right = 0,
				color = STYLE.inactive_label_color,
				string = k == 1 and "—" or "",
			},
			click_script = click,
		})
		slots[ws][k] = slot
		ws_parts[#ws_parts + 1] = slot
	end

	for _, part in ipairs(ws_parts) do
		part:subscribe("mouse.clicked", function(env)
			if env.BUTTON == "right" then
				sbar.exec("aerospace move-node-to-workspace " .. ws)
			end
		end)
	end

	items[ws] = item
	parts[ws] = ws_parts
	pinned_display[ws] = "active"
end

sbar.add("item", { position = "left", width = settings.group_paddings })

local function glyph(app)
	return app_icons[app] or app_icons["Default"] or "·"
end

local focused_ws = nil

-- Three bulk exec calls per refresh: workspace metadata (including empty
-- workspaces), every window's app for the icons, and the focused window.
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
				[[aerospace list-windows --all --format '%{workspace}	%{app-name}' 2>/dev/null; echo '--focused'; aerospace list-windows --focused --format '%{app-name}' 2>/dev/null]],
				function(win_out)
					local apps_by_ws = {}
					local focused_app = nil
					local in_focused = false
					for line in (win_out or ""):gmatch("[^\r\n]+") do
						if line == "--focused" then
							in_focused = true
						elseif in_focused then
							focused_app = line:gsub("^%s+", ""):gsub("%s+$", "")
						else
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
					end

					local new_focus = nil
					for ws, m in pairs(meta) do
						if m.focused then
							new_focus = ws
						end
					end
					local focus_moved = new_focus ~= focused_ws
					focused_ws = new_focus

					-- Spacing goes before a workspace only when a shown one precedes it on the same display.
					local shown_on = {}
					for _, ws in ipairs(workspaces) do
						local m = meta[ws] or { display = 1, focused = false, visible = false }
						local bucket = apps_by_ws[ws]
						local apps = bucket and bucket.list or {}
						local selected = m.focused
						local show = m.visible or #apps > 0

						-- Only re-set display when it actually changed; sketchybar
						-- treats display changes as expensive layout events.
						if pinned_display[ws] ~= m.display then
							pinned_display[ws] = m.display
							for _, part in ipairs(parts[ws]) do
								part:set({ display = m.display })
							end
						end

						local drawing = show and "on" or "off"
						items[ws]:set({
							drawing = drawing,
							icon = { padding_left = shown_on[m.display] and SPACING or 0 },
						})
						for k, slot in ipairs(slots[ws]) do
							local app = apps[k]
							local label = app and glyph(app) or (k == 1 and "—" or "")
							slot:set({
								drawing = (show and (app or k == 1)) and "on" or "off",
								label = { string = label },
							})
						end

						local function paint()
							items[ws]:set({
								icon = {
									color = selected and STYLE.focused_color or STYLE.inactive_icon_color,
								},
							})
							for k, slot in ipairs(slots[ws]) do
								local color = STYLE.inactive_label_color
								if selected and apps[k] ~= nil then
									color = apps[k] == focused_app and STYLE.focused_color or STYLE.active_app_color
								end
								slot:set({ label = { color = color } })
							end
						end
						if focus_moved then
							sbar.animate("tanh", 12, paint)
						else
							paint()
						end

						if show then
							shown_on[m.display] = true
						end
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
