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
		-- Click to focus. 2 rather than 0: the pointer still follows the cursor,
		-- so hover and scroll work over an unfocused window, but keyboard focus
		-- moves only on click.
		follow_mouse = 2,
		float_switch_override_focus = 0,
		sensitivity = -0.1, -- -1.0 to 1.0; 0 is unmodified

		touchpad = {
			natural_scroll = true,
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
