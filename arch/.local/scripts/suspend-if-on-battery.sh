#!/usr/bin/env bash
# Idle-suspend only on battery, and only when nothing is really playing.
#
# The listener that calls this sets ignore_inhibit, because zen keeps an
# org.freedesktop.ScreenSaver inhibit up for as long as a video is loaded --
# paused counts -- which stopped the machine ever sleeping. So the "am I being
# watched" question gets asked here instead, of the players themselves.
set -uo pipefail

# On AC the machine is docked and should stay up.
for f in /sys/class/power_supply/A{C,DP}*/online; do
	[ -r "$f" ] || continue
	[ "$(cat "$f")" = "1" ] && exit 0
done

# A paused or stopped player is not being watched. Only Playing counts, and
# playerctl exits non-zero when there is no player at all.
if command -v playerctl >/dev/null 2>&1; then
	if playerctl -a status 2>/dev/null | grep -qx Playing; then
		exit 0
	fi
fi

systemctl suspend
