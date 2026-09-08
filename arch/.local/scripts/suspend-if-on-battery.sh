#!/usr/bin/env bash
# Idle-suspend only on battery. On AC the machine is docked and should stay up.
set -uo pipefail

for f in /sys/class/power_supply/A{C,DP}*/online; do
	[ -r "$f" ] || continue
	[ "$(cat "$f")" = "1" ] && exit 0
done

systemctl suspend
