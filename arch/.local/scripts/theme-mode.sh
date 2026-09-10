#!/usr/bin/env bash
# Toggle or set the light/dark theme mode and regenerate colours.
#
#   theme-mode.sh           toggle
#   theme-mode.sh dark|light
#   theme-mode.sh --apply   re-apply the current mode, changing nothing
#   theme-mode.sh --current print the current mode
#
# settings.ini is written here rather than stowed: it carries the mode, so a
# tracked copy would either be wrong in one mode or edited in place inside the
# repo. matugen cannot render it -- templates see colours, not the mode.

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/matugen"
MODE_FILE="$STATE_DIR/mode"
mkdir -p "$STATE_DIR"

current() { cat "$MODE_FILE" 2>/dev/null || echo dark; }

case "${1:-}" in
--current) current; exit 0 ;;
--apply) MODE="$(current)" ;;
dark | light) MODE="$1" ;;
"") [ "$(current)" = "dark" ] && MODE=light || MODE=dark ;;
*) echo "theme-mode: unknown argument '$1'" >&2; exit 1 ;;
esac

printf '%s\n' "$MODE" >"$MODE_FILE"

if [ "$MODE" = dark ]; then
	ICONS="Papirus-Dark"
	PREFER_DARK=1
else
	ICONS="Papirus"
	PREFER_DARK=0
fi

gtk_settings() {
	cat <<-EOF
		[Settings]
		gtk-theme-name=Adwaita
		gtk-icon-theme-name=$ICONS
		gtk-font-name=JetBrainsMono Nerd Font 10
		gtk-cursor-theme-name=Adwaita
		gtk-cursor-theme-size=24
		gtk-application-prefer-dark-theme=$PREFER_DARK
		gtk-xft-antialias=1
		gtk-xft-hinting=1
		gtk-xft-hintstyle=hintslight
		gtk-xft-rgba=rgb
	EOF
}

for v in 3.0 4.0; do
	mkdir -p "$HOME/.config/gtk-$v"
	gtk_settings >"$HOME/.config/gtk-$v/settings.ini"
done

# gtk-theme stays Adwaita in both modes: the palette comes from the generated
# colors.css, which overrides every libadwaita named colour.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
	gsettings set org.gnome.desktop.interface color-scheme "prefer-$MODE" 2>/dev/null
	gsettings set org.gnome.desktop.interface gtk-theme Adwaita 2>/dev/null
	gsettings set org.gnome.desktop.interface icon-theme "$ICONS" 2>/dev/null
fi

MATUGEN_MODE="$MODE" exec "$(dirname "$0")/wallpaper.sh" --restore
