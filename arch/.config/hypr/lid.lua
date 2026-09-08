-- Clamshell: the internal panel follows the lid.
--
-- The disable happens here, during config parse, rather than from the switch
-- bind alone. Every config reload re-applies monitors.lua and re-enables the
-- panel; reacting afterwards from an async exec races the reload and loses,
-- putting windows back on a shut screen.

local INTERNAL = "eDP-1"

local function lid_closed()
	for _, path in ipairs({ "/proc/acpi/button/lid/LID/state", "/proc/acpi/button/lid/LID0/state" }) do
		local f = io.open(path, "r")
		if f then
			local body = f:read("*a")
			f:close()
			return body:match("closed") ~= nil
		end
	end
	return false
end

local function external_count()
	local n = 0
	for _, m in ipairs(hl.get_monitors() or {}) do
		if m.name ~= INTERNAL then
			n = n + 1
		end
	end
	return n
end

if lid_closed() and external_count() > 0 then
	hl.monitor({ output = INTERNAL, disabled = true })
end

local lid = os.getenv("HOME") .. "/.local/scripts/hypr-lid.sh"

hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(lid .. " closed"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(lid .. " open"), { locked = true })
hl.exec_cmd(lid .. " sync")
