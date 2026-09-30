-- barpop (helpers/barpop) draws the richer popups. The first require starts
-- it: the old one must be gone before the new one takes its lock, and $PPID
-- is this lua process, so barpop exits with sketchybar. It runs as an app so
-- macOS asks for permissions in its own name.
sbar.exec(
	"pkill -x barpop 2>/dev/null; while pgrep -qx barpop; do sleep 0.05; done; "
		.. "open -g $CONFIG_DIR/helpers/barpop/bin/barpop.app --args daemon $(ps -o ppid= -p $PPID)"
)

-- barpop triggers this with ITEM and OPEN=1/0 as a popup opens and closes.
sbar.add("event", "barpop_popup")

local M = {}

-- Opens popup under item, or closes it if it is already open there.
function M.open(item, popup)
	local rects = {}
	for _, r in pairs(item:query().bounding_rects or {}) do
		table.insert(rects, string.format("%g,%g,%g,%g", r.origin[1], r.origin[2], r.size[1], r.size[2]))
	end
	if #rects > 0 then
		sbar.exec(string.format(
			"$CONFIG_DIR/helpers/barpop/bin/barpop show %s '%s' %s",
			popup,
			table.concat(rects, ";"),
			item.name
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

return M
