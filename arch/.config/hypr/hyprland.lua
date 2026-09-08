-- Hyprland entry point.
--
-- Modules sit alongside this file and are required by name. Keep this file a
-- table of contents: everything substantive belongs in a module.
--
-- Docs: https://wiki.hypr.land/Configuring/

require("monitors_default")

-- Machine-local display layout written by nwg-displays, if one exists. Loaded
-- after the defaults so it overrides them; absent on a fresh machine.
pcall(require, "monitors")
require("looks")
require("input")
require("keybinds")
require("rules")
require("lid")
require("autostart")
