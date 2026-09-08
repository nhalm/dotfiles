#!/usr/bin/env bash
# Float or re-tile every window on the active workspace.
set -uo pipefail

ws="$(hyprctl activeworkspace -j | jq -r '.id')"
floating="$(hyprctl clients -j | jq --argjson w "$ws" '[.[] | select(.workspace.id == $w and .floating)] | length')"
total="$(hyprctl clients -j | jq --argjson w "$ws" '[.[] | select(.workspace.id == $w)] | length')"

action=true
[ "$floating" -eq "$total" ] && action=false

hyprctl clients -j | jq -r --argjson w "$ws" '.[] | select(.workspace.id == $w) | .address' |
	while read -r addr; do
		hyprctl dispatch "hl.dsp.window.float({ action = \"$([ "$action" = true ] && echo enable || echo disable)\", window = \"address:$addr\" })" >/dev/null
	done
