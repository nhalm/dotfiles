-- matugen renders matugen-colors.lua from the wallpaper; the static
-- TokyoNight Storm table below is the fallback before it has ever run.

local function with_alpha(color, alpha)
	if alpha > 1.0 or alpha < 0.0 then
		return color
	end
	return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
end

-- Guarded on a role every render produces: a truncated write still loads,
-- and themed-to-nil is worse than the fallback.
local ok, m = pcall(require, "matugen-colors")
local generated = ok and type(m) == "table" and m.surface ~= nil

local p
if generated then
	p = {
		black = m.surface,
		white = m.on_surface,
		red = m.error,
		-- Material has no success role, and a derived one can land on red --
		-- exactly wrong for a battery or a check.
		green = 0xff9ece6a,
		blue = m.primary,
		yellow = m.tertiary_fixed,
		orange = m.primary_fixed,
		magenta = m.secondary,
		grey = m.outline,
		bg1 = m.surface_container_low,
		bg2 = m.surface_container_high,
		bar_border = m.surface_variant,
		popup_bg = m.surface_container,
		popup_border = m.outline,
	}
else
	p = {
		black = 0xff1d202f, -- TN storm black
		white = 0xffc0caf5, -- TN white (ui/variables)
		red = 0xfff7768e,
		green = 0xff9ece6a,
		blue = 0xff7aa2f7,
		yellow = 0xffe0af68,
		orange = 0xffff9e64,
		magenta = 0xffbb9af7,
		grey = 0xff565f89, -- comments/disabled
		bg1 = 0xff1f2335, -- darker panel
		bg2 = 0xff24283b, -- card/chip bg
		bar_border = 0xff292e42, -- highlight line
		popup_bg = 0xff1f2335,
		popup_border = 0xff565f89,
	}
end

return {
	-- Core
	black = p.black,
	white = p.white,
	red = p.red,
	green = p.green,
	blue = p.blue,
	yellow = p.yellow,
	orange = p.orange,
	magenta = p.magenta,
	grey = p.grey,
	transparent = 0x00000000,

	-- Bar / popups / backgrounds
	bar = {
		-- Deliberately transparent: the brackets carry the colour.
		bg = 0x00000000,
		border = p.bar_border,
	},
	popup = {
		bg = with_alpha(p.popup_bg, 0.75),
		border = p.popup_border,
	},

	-- Extra background shades (chips/brackets)
	bg1 = p.bg1,
	bg2 = p.bg2,

	with_alpha = with_alpha,
}
