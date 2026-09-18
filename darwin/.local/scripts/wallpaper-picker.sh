#!/usr/bin/env bash
# Interactive wallpaper picker, bound to caps+w in aerospace.toml.
#
#   wallpaper-picker.sh              pick one
#   wallpaper-picker.sh --preview F  render one entry (fzf calls this itself)
#
# Thumbnails go through the kitty graphics protocol, which Ghostty implements.
# Beside each is the palette matugen would derive from it.

set -uo pipefail

DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PREVIEW_ROLES='primary secondary tertiary error surface on_surface outline'

system_mode() {
	if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
		echo dark
	else
		echo light
	fi
}

if [ "${1:-}" = "--preview" ]; then
	file="${2:-}"
	[ -f "$file" ] || exit 0

	if command -v chafa >/dev/null 2>&1; then
		# -f kitty explicitly: chafa's terminal probe does not reach Ghostty
		# from inside an fzf preview.
		chafa -f kitty --size "${FZF_PREVIEW_COLUMNS:-60}x20" --animate off "$file" 2>/dev/null
	else
		echo "(chafa not installed -- no thumbnail)"
	fi

	echo
	command -v matugen >/dev/null 2>&1 || exit 0
	command -v jq >/dev/null 2>&1 || exit 0

	# --dry-run writes nothing, so scrolling cannot clobber the live palette.
	matugen image "$file" -m "$(system_mode)" --source-color-index 0 \
		--dry-run --json hex 2>/dev/null |
		jq -r --arg roles "$PREVIEW_ROLES" '
			($roles | split(" ")) as $want
			| .colors
			| to_entries[]
			| select(.key as $k | $want | index($k))
			| "\(.key) \(.value.default.color // .value.default)"
		' 2>/dev/null |
		while read -r role hex; do
			hex="${hex#\#}"
			printf '\033[48;2;%d;%d;%dm      \033[0m %s\n' \
				"0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}" "$role"
		done
	exit 0
fi

command -v fzf >/dev/null 2>&1 || {
	echo "wallpaper-picker: fzf not installed" >&2
	exit 1
}

[ -d "$DIR" ] || {
	echo "wallpaper-picker: $DIR does not exist" >&2
	echo "  setup clones nhalm/wallpapers there; run ./setup.sh" >&2
	exit 1
}

# Also set here: AeroSpace can detect the window before Ghostty's --title lands.
printf '\033]0;wallpaper-picker\007'

selection="$(
	find -L "$DIR" -type f \
		\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null |
		sort |
		fzf --preview "'$HERE/wallpaper-picker.sh' --preview {}" \
			--preview-window 'right:55%:noborder' \
			--prompt 'wallpaper> ' \
			--header 'enter apply · esc cancel' \
			--with-nth -1 --delimiter /
)" || exit 0

[ -n "$selection" ] || exit 0
exec "$HERE/wallpaper.sh" "$selection"
