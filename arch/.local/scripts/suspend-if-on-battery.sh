#!/usr/bin/env bash
# Idle-suspend only on battery, and only when nothing is really playing.
set -uo pipefail

for f in /sys/class/power_supply/A{C,DP}*/online; do
	[ -r "$f" ] || continue
	[ "$(cat "$f")" = "1" ] && exit 0
done

if command -v playerctl >/dev/null 2>&1; then
	if playerctl -a status 2>/dev/null | grep -qx Playing; then
		exit 0
	fi
fi

systemctl suspend
