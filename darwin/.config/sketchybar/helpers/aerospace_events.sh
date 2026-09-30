#!/bin/sh
# Relays aerospace's events to sketchybar as aerospace_workspace_change. A
# closed window has no event of its own, but focus moves when it goes.
# Reconnects if aerospace restarts; ends with sketchybar.
PATH="/opt/homebrew/bin:$PATH"
while pgrep -qx sketchybar; do
	aerospace subscribe --no-send-initial focus-changed focused-workspace-changed window-detected binding-triggered 2>/dev/null |
		while read -r _; do sketchybar --trigger aerospace_workspace_change; done
	sleep 1
done
