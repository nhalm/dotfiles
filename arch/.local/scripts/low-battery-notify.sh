#!/usr/bin/env bash
# Warn once per threshold crossing while discharging.
set -uo pipefail

BAT="${BATTERY:-/sys/class/power_supply/BAT0}"
STATE="${XDG_RUNTIME_DIR:-/tmp}/low-battery-warned"

[ -r "$BAT/capacity" ] || exit 0

while true; do
	pct="$(cat "$BAT/capacity")"
	status="$(cat "$BAT/status")"
	warned="$(cat "$STATE" 2>/dev/null || echo 100)"

	if [ "$status" = "Discharging" ]; then
		for level in 20 10 5; do
			if [ "$pct" -le "$level" ] && [ "$warned" -gt "$level" ]; then
				urgency=critical
				[ "$level" -eq 20 ] && urgency=normal
				notify-send -u "$urgency" "Battery at ${pct}%" "Plug in soon."
				echo "$level" >"$STATE"
				break
			fi
		done
	else
		echo 100 >"$STATE"
	fi

	sleep 60
done
