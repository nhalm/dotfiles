-- Rendered by matugen into ~/.config/sketchybar/. Edit this, not the output.
-- Every role as 0xAARRGGBB; colors.lua maps them onto the names items use.
return {
<* for name, value in colors *>
	{{name}} = 0xff{{value.default.hex_stripped}},
<* endfor *>
}
