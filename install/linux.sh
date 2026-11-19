# Arch / CachyOS. Sourced by setup.sh.

PLAN_PACKAGES="sudo pacman -Syu + install/pacman.txt; yay install/aur.txt"
PLAN_CONFIGURE="wallpapers, hyprland-quickshell, palette seed, theme mode, qt6ct.conf (if missing), blueman tray off, gcr ssh agent, wayvnc key + config (if missing), Zen theme link"

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

	# wayvnc's RSA-AES key; per machine, never in the repo.
	local vnckey="$HOME/.config/wayvnc/rsa_key.pem"
	[ -f "$vnckey" ] || ssh-keygen -q -m pem -t rsa -b 3072 -N "" -C wayvnc -f "$vnckey"
	rm -f "$vnckey.pub"
	render_wayvnc_config


	link_zen_theme
}

# The VNC password is appended from 1Password, never passed in argv.
render_wayvnc_config() {
	local conf="$HOME/.config/wayvnc/config"
	[ -f "$conf" ] && [ ! -L "$conf" ] && return
	rm -f "$conf"
	(
		umask 077
		{
			grep -v '^#' "$DOTFILES/install/wayvnc.conf"
			printf 'password='
			op read -n "op://Private/BigBox VNC/password"
			echo
		} >"$conf.tmp" && mv "$conf.tmp" "$conf"
	) || { rm -f "$conf.tmp"; echo "  wayvnc config not rendered (op read failed)"; }
}
