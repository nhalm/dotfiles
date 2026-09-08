-- Gaps, borders, decoration, animations.
-- https://wiki.hypr.land/Configuring/Variables/

-- matugen regenerates matugen-colors.lua from the wallpaper; colors.lua is the
-- fallback before any wallpaper has been set.
local ok, generated = pcall(require, "matugen-colors")
local c = ok and generated or require("colors")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,
		border_size = 2,
		col = {
			active_border = { colors = { c.primary, c.secondary }, angle = 45 },
			inactive_border = c.outline_variant,
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},

	dwindle = {
		preserve_split = true,
	},

	master = {
		new_status = "master",
	},

	misc = {
		-- No mascot wallpaper. Nothing draws a background instead, so this is a
		-- flat colour until hyprpaper or swaybg is set up.
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
})

-- Animation curves, then the animations that use them.
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

local animations = {
	{ leaf = "global", speed = 10, bezier = "default" },
	{ leaf = "border", speed = 5.39, bezier = "easeOutQuint" },
	{ leaf = "windows", speed = 4.79, spring = "easy" },
	{ leaf = "windowsIn", speed = 4.1, spring = "easy", style = "popin 87%" },
	{ leaf = "windowsOut", speed = 1.49, bezier = "linear", style = "popin 87%" },
	{ leaf = "fadeIn", speed = 1.73, bezier = "almostLinear" },
	{ leaf = "fadeOut", speed = 1.46, bezier = "almostLinear" },
	{ leaf = "fade", speed = 3.03, bezier = "quick" },
	{ leaf = "layers", speed = 3.81, bezier = "easeOutQuint" },
	{ leaf = "layersIn", speed = 4, bezier = "easeOutQuint", style = "fade" },
	{ leaf = "layersOut", speed = 1.5, bezier = "linear", style = "fade" },
	{ leaf = "fadeLayersIn", speed = 1.79, bezier = "almostLinear" },
	{ leaf = "fadeLayersOut", speed = 1.39, bezier = "almostLinear" },
	{ leaf = "workspaces", speed = 1.94, bezier = "almostLinear", style = "fade" },
	{ leaf = "workspacesIn", speed = 1.21, bezier = "almostLinear", style = "fade" },
	{ leaf = "workspacesOut", speed = 1.94, bezier = "almostLinear", style = "fade" },
	{ leaf = "zoomFactor", speed = 7, bezier = "quick" },
}

for _, a in ipairs(animations) do
	a.enabled = true
	hl.animation(a)
end
