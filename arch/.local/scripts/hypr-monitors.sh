#!/usr/bin/env bash
# Re-pack enabled monitors left-to-right from x=0 with no gaps or overlaps,
# preserving their current order and using each monitor's real logical width.
#
# Positions therefore follow from order + scale rather than being stored, so a
# scale change can never leave the layout inconsistent. Matching is by
# description: connector names are not stable across boots.

set -uo pipefail

# Let Hyprland finish applying monitor rules after a hotplug.
sleep "${HYPR_MONITORS_DELAY:-0.4}"

hypr_eval() {
	local out
	out="$(hyprctl eval "$1" 2>&1)"
	case "$out" in
	error*) echo "hypr-monitors: $out" >&2; return 1 ;;
	esac
}

x=0
while IFS=$'\t' read -r desc lw; do
	[ -n "$desc" ] || continue
	hypr_eval "hl.monitor({ output = \"desc:$desc\", position = \"${x}x0\" })"
	x=$((x + lw))
done < <(hyprctl monitors -j 2>/dev/null |
	jq -r 'sort_by(.x)[] | "\(.description)\t\((.width / .scale) | floor)"' 2>/dev/null)
