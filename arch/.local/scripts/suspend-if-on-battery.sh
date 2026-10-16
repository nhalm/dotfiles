#!/usr/bin/env bash
# Idle-suspend only on battery, and only when nothing is really playing.
set -uo pipefail

discharging=0
for f in /sys/class/power_supply/BAT*/status; do
	[ -r "$f" ] || continue
	[ "$(cat "$f")" = "Discharging" ] && discharging=1
done
[ "$discharging" = 1 ] || exit 0

if command -v playerctl >/dev/null 2>&1; then
	if playerctl -a status 2>/dev/null | grep -qx Playing; then
		exit 0
	fi
fi

systemctl suspend
