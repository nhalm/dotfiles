#!/usr/bin/env bash
# Match the internal panel to the lid state (clamshell mode).
#
# Uses `hyprctl eval` with the Lua monitor API, NOT `hyprctl keyword`. Every
# clamshell recipe online uses keyword, which a Lua-configured Hyprland rejects
# outright -- "keyword can't work with non-legacy parsers. Use eval." -- while
# still exiting 0, so the failure is silent.
#
# Driven by the kernel's lid state rather than by which switch edge fired.
# switch:on / switch:off mapping for lids has been unreliable in the Lua config
# (hyprwm/Hyprland#14858), and this way the script is also correct when run by
# hand to resync. The edge Hyprland passes is only a fallback for when
# /proc/acpi is unreadable.
#
# The panel is disabled only while another display is connected -- closing the
# lid on its own would otherwise leave Hyprland with no output. That case needs
# no handling: logind only uses HandleLidSwitchDocked=ignore when more than one
# display is connected, so an undocked lid close still suspends normally.
#
# Usage: hypr-lid.sh [closed|open]

set -uo pipefail

INTERNAL="${HYPR_INTERNAL_MONITOR:-eDP-1}"
INTERNAL_MODE="${HYPR_INTERNAL_MODE:-preferred}"
INTERNAL_POSITION="${HYPR_INTERNAL_POSITION:-auto}"
INTERNAL_SCALE="${HYPR_INTERNAL_SCALE:-1.5}"

# hyprctl exits 0 even when the Lua call errors, so inspect the output.
hypr_eval() {
	local out
	out="$(hyprctl eval "$1" 2>&1)"
	case "$out" in
	error*) echo "hypr-lid: $out" >&2; return 1 ;;
	esac
}

lid_state() {
	local f
	for f in /proc/acpi/button/lid/*/state; do
		[ -r "$f" ] || continue
		awk '{print $2}' "$f"
		return
	done
	echo "unknown"
}

# Re-pack enabled monitors left-to-right from x=0, so disabling the internal
# panel does not leave a dead region the cursor can strand in.
repack_monitors() {
	local x=0 desc lw
	while IFS=$'\t' read -r desc lw; do
		[ -n "$desc" ] || continue
		hypr_eval "hl.monitor({ output = \"desc:$desc\", position = \"${x}x0\" })"
		x=$((x + lw))
	done < <(hyprctl monitors -j 2>/dev/null |
		jq -r 'sort_by(.x)[] | "\(.description)\t\((.width / .scale) | floor)"' 2>/dev/null)
}

# Monitors Hyprland currently has enabled, excluding the internal panel.
external_count() {
	hyprctl monitors -j 2>/dev/null |
		jq --arg m "$INTERNAL" '[.[] | select(.name != $m)] | length' 2>/dev/null || echo 0
}

LOG="${XDG_RUNTIME_DIR:-/tmp}/hypr-lid.log"
state="$(lid_state)"
[ "$state" = "unknown" ] && state="${1:-}"
printf '%s invoked arg=%s state=%s externals=%s\n' "$(date +%T)" "${1:-none}" "$state" "$(external_count)" >>"$LOG"

case "$state" in
closed)
	if [ "$(external_count)" -gt 0 ]; then
		ws="$(hyprctl monitors -j 2>/dev/null |
			jq -r --arg m "$INTERNAL" '.[] | select(.name == $m) | select(.activeWorkspace.id != null) | .activeWorkspace.id' 2>/dev/null)"
		windows="$(hyprctl workspaces -j 2>/dev/null |
			jq -r --arg w "${ws:-0}" '.[] | select(.id == ($w | tonumber)) | .windows' 2>/dev/null)"

		hypr_eval "hl.monitor({ output = \"$INTERNAL\", disabled = true })" || exit 1

		# Hyprland migrates the workspace to a remaining monitor but leaves that
		# monitor showing its own, so the windows arrive hidden.
		repack_monitors

		if [ -n "$ws" ] && [ "${windows:-0}" -gt 0 ] 2>/dev/null; then
			hyprctl dispatch "hl.dsp.focus({ workspace = $ws })" >/dev/null 2>&1
		fi
	fi
	;;
open)
	# Reload rather than re-applying a hardcoded rule: the saved layout lives in
	# ~/.config/hypr/monitors.lua (written by nwg-displays), and reloading
	# restores it exactly instead of fighting it with position = auto, which
	# re-places the panel to the right of the externals. Reload does not re-fire
	# hyprland.start, so autostart is not run again.
	hyprctl reload >/dev/null 2>&1 ||
		hypr_eval "hl.monitor({ output = \"$INTERNAL\", disabled = false, mode = \"$INTERNAL_MODE\", position = \"$INTERNAL_POSITION\", scale = \"$INTERNAL_SCALE\" })"
	;;
*)
	echo "hypr-lid: cannot determine lid state" >&2
	exit 1
	;;
esac
