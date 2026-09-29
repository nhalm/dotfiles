local colors = require("colors")

-- The notch_* keys apply only to the built-in display, where the bar is the
-- notch's height.
sbar.bar({
	height = 36,
	notch_display_height = 32,
	notch_width = 200,
	color = colors.bar.bg,
	padding_right = 2,
	padding_left = 2,
})
