-- Monitors. https://wiki.hypr.land/Configuring/Monitors/

-- Catch-all so an unknown external display still comes up.
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- Built-in panel. 1.5x is the readable scale on this one.
hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = "1.5",
})
