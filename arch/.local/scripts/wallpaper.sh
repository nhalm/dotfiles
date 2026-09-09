#!/usr/bin/env bash
# Set the wallpaper and regenerate every app's colours from it.
#
#   wallpaper.sh <image>    set a specific image
#   wallpaper.sh --random   pick at random
#   wallpaper.sh --restore  re-apply the remembered one
#
# Choosing one interactively is the quickshell carousel's job:
# `qs ipc call wallpaper toggle`.
#
# matugen renders the templates in ~/.config/matugen/config.toml; consumers are
# then told to reload. The chosen path is remembered so the session can restore
# it at startup.

set -uo pipefail

DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
MODE="${MATUGEN_MODE:-$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/matugen/mode" 2>/dev/null || echo dark)}"

pick() {
	find -L "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null
}

case "${1:-}" in
--random) IMAGE="$(pick | shuf -n1)" ;;
--restore) IMAGE="$(cat "$STATE" 2>/dev/null)" ;;
"") echo "usage: wallpaper.sh <image> | --random | --restore" >&2; exit 1 ;;
*) IMAGE="$1" ;;
esac

[ -n "${IMAGE:-}" ] && [ -f "$IMAGE" ] || { echo "wallpaper: no image" >&2; exit 1; }

# Setup runs this from a TTY to seed the palette; there is no compositor to show
# an image on yet, and the session applies it at startup with --restore.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
	# The AUR swww package installs its binaries as awww; upstream swww uses swww.
	SWWW="$(command -v awww || command -v swww)"
	DAEMON="$(command -v awww-daemon || command -v swww-daemon)"

	if ! "$SWWW" query >/dev/null 2>&1; then
		"$DAEMON" >/dev/null 2>&1 &
		sleep 0.5
	fi
	"$SWWW" img "$IMAGE" --transition-type grow --transition-fps 60 --transition-duration 1
fi

matugen image "$IMAGE" -m "$MODE" --source-color-index 0 >/dev/null || echo "wallpaper: matugen failed" >&2

mkdir -p "$(dirname "$STATE")"
printf '%s\n' "$IMAGE" >"$STATE"

# Apply the new border colours directly rather than reloading the config:
# a reload re-applies the monitor rules too, which makes every display flicker
# and shuffle on each theme change.
apply_hypr_colors() {
	local f="$HOME/.config/hypr/matugen-colors.lua" primary secondary outline
	[ -r "$f" ] || return 0
	primary="$(grep -oP '^\tprimary = "\K[^"]+' "$f" | head -1)"
	secondary="$(grep -oP '^\tsecondary = "\K[^"]+' "$f" | head -1)"
	outline="$(grep -oP '^\toutline_variant = "\K[^"]+' "$f" | head -1)"
	[ -n "$primary" ] || return 0
	hyprctl eval "hl.config({ general = { col = { active_border = { colors = {\"$primary\", \"$secondary\"}, angle = 45 }, inactive_border = \"$outline\" } } })" >/dev/null 2>&1
}

qs ipc call theme-manager reload >/dev/null 2>&1
swaync-client --reload-css >/dev/null 2>&1
apply_hypr_colors
