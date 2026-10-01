#!/bin/sh
# Relays aerospace's events to sketchybar as aerospace_workspace_change. A
# closed window has no event of its own, but focus moves when it goes.
# Reconnects if aerospace restarts; ends with sketchybar. aerospace subscribe
# outlives a closed pipe, so it is killed with its reader and on TERM.
PATH="/opt/homebrew/bin:$PATH"
trap 'pkill -P $$; exit' TERM
while pgrep -qx sketchybar; do
	aerospace subscribe --no-send-initial focus-changed focused-workspace-changed window-detected binding-triggered 2>/dev/null | {
		while read -r _; do sketchybar --trigger aerospace_workspace_change || break; done
		pkill -P $$
	} &
	wait
	sleep 1
done
