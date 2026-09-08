#!/usr/bin/env bash
# Toggle or set the light/dark theme mode and regenerate colours.
#
#   theme-mode.sh           toggle
#   theme-mode.sh dark|light
#   theme-mode.sh --current print the current mode

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/matugen"
MODE_FILE="$STATE_DIR/mode"
mkdir -p "$STATE_DIR"

current() { cat "$MODE_FILE" 2>/dev/null || echo dark; }

case "${1:-}" in
--current) current; exit 0 ;;
dark | light) MODE="$1" ;;
"") [ "$(current)" = "dark" ] && MODE=light || MODE=dark ;;
*) echo "theme-mode: unknown argument '$1'" >&2; exit 1 ;;
esac

printf '%s\n' "$MODE" >"$MODE_FILE"

gsettings set org.gnome.desktop.interface color-scheme "prefer-$MODE" 2>/dev/null
gsettings set org.gnome.desktop.interface gtk-theme \
	"$([ "$MODE" = dark ] && echo Adwaita-dark || echo Adwaita)" 2>/dev/null

MATUGEN_MODE="$MODE" exec "$(dirname "$0")/wallpaper.sh" --restore
