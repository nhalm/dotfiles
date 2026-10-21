# macOS. Sourced by setup.sh.

PLAN_PACKAGES="install Homebrew if missing, trust taps, brew bundle install/upgrade install/Brewfile"
PLAN_CONFIGURE="wallpapers, login item loading the ssh key from Keychain, Karabiner config (if missing), ghostty + docker compose links, colima sshConfig off, SbarLua, barpop build, hide menu bar, start sketchybar + borders, Zen theme link, brew cleanup"

install_packages() {
	[ -x /opt/homebrew/bin/brew ] ||
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	eval "$(/opt/homebrew/bin/brew shellenv)"
	# Homebrew ignores third-party taps it hasn't been told to trust.
	brew trust --tap felixkratz/formulae nikitabobko/tap hashicorp/tap
	# --verbose: otherwise nothing prints until every entry is done.
	brew bundle --verbose --file "$DOTFILES/install/Brewfile"
}

configure() {
	install_wallpapers

	# Loads the ssh key from Keychain into launchd's agent at every login, so
	# nothing prompts for the passphrase after a reboot. Copied: launchd skips
	# symlinked plists at login.
	local plist="$HOME/Library/LaunchAgents/local.ssh-add-keychain.plist"
	mkdir -p "${plist%/*}"
	cp "$DOTFILES/install/ssh-add.plist" "$plist"
	launchctl bootout "gui/$(id -u)/local.ssh-add-keychain" 2>/dev/null || true
	launchctl bootstrap "gui/$(id -u)" "$plist"

	# The cask installs only the app; snacks.nvim probes for the binary.
	mkdir -p "$HOME/.local/bin"
	ln -sfn /Applications/Ghostty.app/Contents/MacOS/ghostty "$HOME/.local/bin/ghostty"

	# Copied, not linked: Karabiner rewrites its own file.
	local kb="$HOME/.config/karabiner/karabiner.json"
	if [ -L "$kb" ] || [ ! -e "$kb" ]; then
		mkdir -p "${kb%/*}"
		rm -f "$kb"
		cp "$DOTFILES/install/karabiner.json" "$kb"
	fi

	mkdir -p "$HOME/.docker/cli-plugins"
	ln -sfn /opt/homebrew/bin/docker-compose "$HOME/.docker/cli-plugins/docker-compose"

	# colima would add an Include with an absolute path to ~/.ssh/config,
	# which is linked into this repo.
	local f
	for f in "$(colima template --print)" "$HOME"/.colima/*/colima.yaml; do
		[ -f "$f" ] && yq -i '.sshConfig = false' "$f"
	done

	# SbarLua has no formula. Delete the .so to rebuild.
	if [ ! -f "$HOME/.local/share/sketchybar_lua/sketchybar.so" ]; then
		local tmp
		tmp="$(mktemp -d)"
		git_public clone --quiet https://github.com/FelixKratz/SbarLua.git "$tmp"
		(cd "$tmp" && make install)
		rm -rf "$tmp"
	fi

	sync_repo https://github.com/nhalm/barpop "$HOME/.local/share/barpop"
	make -C "$HOME/.local/share/barpop" >/dev/null

	defaults write NSGlobalDomain _HIHideMenuBar -bool true
	brew services start felixkratz/formulae/borders >/dev/null || true
	brew services start sketchybar >/dev/null || true

	link_zen_theme
	brew cleanup
}
