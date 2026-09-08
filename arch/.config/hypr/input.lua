-- Keyboard, pointer, touchpad, gestures.
-- https://wiki.hypr.land/Configuring/Variables/#input

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		natural_scroll = true,
		numlock_by_default = true,
		follow_mouse = 1,
		sensitivity = -0.1, -- -1.0 to 1.0; 0 is unmodified

		touchpad = {
			natural_scroll = true,
		numlock_by_default = true,
			disable_while_typing = true,
			tap_button_map = "lrm",
		},
	},
})

-- Three-finger horizontal swipe moves between workspaces.
hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})
