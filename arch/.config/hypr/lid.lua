-- Clamshell behaviour: closing the lid turns off the internal panel and leaves
-- the externals running, rather than suspending.
--
-- The suspend half needs no configuration. logind picks HandleLidSwitchDocked
-- (which defaults to "ignore") whenever more than one display is connected, so
-- the machine already stays awake while docked and still suspends when the lid
-- is closed on its own.
--
-- Both edges run the same script; it reads the kernel lid state rather than
-- trusting the edge, because switch:on/switch:off has been unreliable for lids
-- in the Lua config (hyprwm/Hyprland#14858).
--
-- locked = true so it still fires with the session locked.

local lid = os.getenv("HOME") .. "/.local/scripts/hypr-lid.sh"

hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(lid .. " closed"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(lid .. " open"), { locked = true })
