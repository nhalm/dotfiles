#!/usr/bin/env bash
# Set the wallpaper and regenerate every app's colours from it.
#
#   wallpaper.sh <image>   set a specific image
#   wallpaper.sh           pick one with fuzzel
#   wallpaper.sh --random  pick at random
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
"") IMAGE="$(pick | fuzzel --dmenu --width 60)" ;;
*) IMAGE="$1" ;;
esac

[ -n "${IMAGE:-}" ] && [ -f "$IMAGE" ] || { echo "wallpaper: no image" >&2; exit 1; }

# The AUR swww package installs its binaries as awww; upstream swww uses swww.
SWWW="$(command -v awww || command -v swww)"
DAEMON="$(command -v awww-daemon || command -v swww-daemon)"

if ! "$SWWW" query >/dev/null 2>&1; then
	"$DAEMON" >/dev/null 2>&1 &
	sleep 0.5
fi
"$SWWW" img "$IMAGE" --transition-type grow --transition-fps 60 --transition-duration 1

matugen image "$IMAGE" -m "$MODE" --source-color-index 0 >/dev/null || echo "wallpaper: matugen failed" >&2

mkdir -p "$(dirname "$STATE")"
printf '%s\n' "$IMAGE" >"$STATE"

qs ipc call theme-manager reload >/dev/null 2>&1
swaync-client --reload-css >/dev/null 2>&1
hyprctl reload >/dev/null 2>&1
