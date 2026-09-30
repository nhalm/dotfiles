-- barpop (helpers/barpop) draws the richer popups. The first require starts
-- it: the old one must be gone before the new one takes its lock, and it
-- exits with sketchybar. It runs as an app so macOS asks for permissions in
-- its own name. A reload (wallpaper.sh runs one) keeps a barpop that serves
-- this sketchybar and is newer than its binary, so an open popup survives it.
-- pgrep skips its own ancestors, sketchybar among them, without -a.
local launch = "open -g $CONFIG_DIR/helpers/barpop/bin/barpop.app --args daemon $(pgrep -axn sketchybar)"
sbar.exec(
	"bin=$CONFIG_DIR/helpers/barpop/bin/barpop.app/Contents/MacOS/barpop; bar=$(pgrep -axn sketchybar); "
		.. "pid=$(pgrep -x barpop | head -1); "
		.. "if [ -n \"$pid\" ] && ps -o args= -p $pid | grep -q \" daemon $bar$\" && "
		.. "[ $(LC_ALL=C date -j -f '%a %b %e %T %Y' \"$(LC_ALL=C ps -o lstart= -p $pid | xargs)\" +%s) -ge $(stat -f %m $bin) ]; "
		.. "then exit 0; fi; "
		.. "pkill -x barpop 2>/dev/null; while pgrep -qx barpop; do sleep 0.05; done; "
		.. launch
)

-- barpop triggers this with ITEM and OPEN=1/0 as a popup opens and closes.
sbar.add("event", "barpop_popup")
-- Shortcuts trigger this with POPUP=<name> to open a popup from the keyboard.
sbar.add("event", "barpop_open")

local M = {}

-- Opens popup under item, or closes it if it is already open there.
-- keyboard: opened by a shortcut, so it stays open until the pointer has
-- been over it and left.
function M.open(item, popup, keyboard)
	local rects = {}
	for _, r in pairs(item:query().bounding_rects or {}) do
		table.insert(rects, string.format("%g,%g,%g,%g", r.origin[1], r.origin[2], r.size[1], r.size[2]))
	end
	if #rects > 0 then
		-- If barpop has died, start it again before asking it for the popup.
		sbar.exec(string.format(
			"pgrep -qx barpop || { %s; sleep 1; }; $CONFIG_DIR/helpers/barpop/bin/barpop show %s '%s' %s%s",
			launch,
			popup,
			table.concat(rects, ";"),
			item.name,
			keyboard and " keyboard" or ""
		))
	end
end

-- Calls paint(open) whenever item's popup opens or closes.
function M.watch(item, paint)
	item:subscribe("barpop_popup", function(env)
		if env.ITEM == item.name then
			paint(env.OPEN == "1")
		end
	end)
end

-- Opens item's popup on `sketchybar --trigger barpop_open POPUP=<popup>`.
function M.shortcut(item, popup)
	item:subscribe("barpop_open", function(env)
		if env.POPUP == popup then
			M.open(item, popup, true)
		end
	end)
end

return M
