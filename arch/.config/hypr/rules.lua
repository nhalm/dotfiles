-- Window rules. https://wiki.hypr.land/Configuring/Window-Rules/

-- Stops apps that spam maximize events from fighting the tiling layout.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- XWayland drag surfaces have no class or title and should never steal focus.
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

-- Dialogs and utilities that are better floating than tiled.
hl.window_rule({
	name = "float-1password",
	match = { class = "^(1Password)$" },
	float = true,
})

hl.window_rule({
	name = "float-audio-mixer",
	match = { class = "^(org.pulseaudio.pavucontrol)$" },
	float = true,
})

hl.window_rule({
	name = "float-nm-connection-editor",
	match = { class = "^(nm-connection-editor)$" },
	float = true,
})

-- Picture-in-picture stays on top and follows you between workspaces.
hl.window_rule({
	name = "pip-stays-visible",
	match = { title = "^(Picture-in-Picture)$" },
	float = true,
	pin = true,
})
