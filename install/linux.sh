# Arch / CachyOS. Sourced by setup.sh.

install_packages() {
	grep -v '^\s*\(#\|$\)' "$DOTFILES/install/pacman.txt" | sudo pacman -Syu --needed --noconfirm -
	grep -v '^\s*\(#\|$\)' "$DOTFILES/install/aur.txt" | yay -S --needed --noconfirm -
}

configure() {
	mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos/Recordings"
	install_wallpapers
	sync_repo https://github.com/nhalm/hyprland-quickshell "$HOME/.config/quickshell"

	# Render the palette before anything reads it.
	[ -s "$HOME/.local/state/wallpaper" ] || "$HOME/.local/scripts/wallpaper.sh" --random
	"$HOME/.local/scripts/theme-mode.sh" --apply >/dev/null

	# qt6ct expands neither ~ nor $HOME, and rewrites its file on save.
	local qt6ct="$HOME/.config/qt6ct/qt6ct.conf"
	if [ ! -f "$qt6ct" ]; then
		mkdir -p "${qt6ct%/*}"
		sed "s|@HOME@|$HOME|" "$DOTFILES/install/qt6ct.conf" >"$qt6ct"
	fi

	# blueman-applet runs only as the pairing agent; status lives in the bar.
	gsettings set org.blueman.general plugin-list "['!StatusNotifierItem']"

	# gcr's agent keeps the key's passphrase in the login keyring.
	systemctl --user disable --now ssh-agent.socket 2>/dev/null || true
	systemctl --user enable --now gcr-ssh-agent.socket

	link_zen_theme
}
