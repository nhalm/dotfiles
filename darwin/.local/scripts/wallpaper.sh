#!/usr/bin/env bash
# Set the wallpaper and regenerate every app's colours from it.
#
#   wallpaper.sh <image>    set a specific image
#   wallpaper.sh --restore  re-apply the remembered one
#
# Choosing one interactively is wallpaper-picker.sh's job (caps+w).

set -uo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"

# AppleInterfaceStyle only exists while dark mode is on, so a failed read is
# light mode, not an error.
system_mode() {
	if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
		echo dark
	else
		echo light
	fi
}

MODE="${MATUGEN_MODE:-$(system_mode)}"

case "${1:-}" in
--restore) IMAGE="$(cat "$STATE" 2>/dev/null)" ;;
"" | -h | --help)
	echo "usage: wallpaper.sh <image> | --restore" >&2
	exit 1
	;;
*) IMAGE="$1" ;;
esac

[ -n "${IMAGE:-}" ] && [ -f "$IMAGE" ] || {
	echo "wallpaper: no image" >&2
	exit 1
}

# "every desktop" is every display, not every Space. Reaching the other Spaces
# means writing Dock's sqlite store, which changes shape between releases.
osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$IMAGE\"" \
	>/dev/null 2>&1 || echo "wallpaper: could not set the desktop picture" >&2

command -v matugen >/dev/null 2>&1 || {
	echo "wallpaper: matugen not installed (mise install)" >&2
	exit 1
}

# -c explicitly: matugen resolves its default config under
# ~/Library/Application Support on macOS, not ~/.config, so it silently loads
# zero templates without this.
matugen -c "$HOME/.config/matugen/config.toml" \
	image "$IMAGE" -m "$MODE" --source-color-index 0 >/dev/null ||
	echo "wallpaper: matugen failed" >&2

mkdir -p "$(dirname "$STATE")"
printf '%s\n' "$IMAGE" >"$STATE"

command -v sketchybar >/dev/null 2>&1 && sketchybar --reload >/dev/null 2>&1

# borders takes its colours as arguments, so re-running it retints the live
# instance without a restart. aerospace.toml carries the static values, which
# are what run at login.
apply_border_colors() {
	local f="$HOME/.config/sketchybar/matugen-colors.lua" primary secondary outline
	[ -r "$f" ] || return 0
	command -v borders >/dev/null 2>&1 || return 0

	primary="$(sed -n 's/^[[:space:]]*primary = \(0x[0-9a-f]*\),.*/\1/p' "$f" | head -1)"
	secondary="$(sed -n 's/^[[:space:]]*secondary = \(0x[0-9a-f]*\),.*/\1/p' "$f" | head -1)"
	outline="$(sed -n 's/^[[:space:]]*outline_variant = \(0x[0-9a-f]*\),.*/\1/p' "$f" | head -1)"
	[ -n "$primary" ] || return 0

	borders \
		active_color="$primary" \
		inactive_color="${outline:-$secondary}" \
		width=5.0 >/dev/null 2>&1
}
apply_border_colors

echo "palette rendered from $(basename "$IMAGE") ($MODE)"
echo "  ghostty: reload with Cmd+Shift+, or open a new window"
