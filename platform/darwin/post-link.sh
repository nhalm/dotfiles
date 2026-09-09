# macOS steps that need the stowed configs in place.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- tmux ---------------------------------------------------------------
# tmux is macOS-only now; Linux uses herdr. TPM is vendored in darwin/tmux,
# but the plugin manager expects it under ~/.tmux/plugins/tpm.
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
	echo "installing tmux plugin manager..."
	git_public clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
	echo "TPM already installed"
fi

# --- docker compose plugin ----------------------------------------------
if command -v docker-compose >/dev/null 2>&1; then
	mkdir -p "$HOME/.docker/cli-plugins"
	ln -sfn "$(brew --prefix)/bin/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"
	echo "docker compose plugin configured"
fi

# --- kitty theme --------------------------------------------------------
kitty_dir="$HOME/.config/kitty"
if [ ! -f "$kitty_dir/tokyonight_storm.conf" ]; then
	echo "downloading kitty tokyonight-storm theme..."
	mkdir -p "$kitty_dir"
	curl -fsSL "https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/kitty/tokyonight_storm.conf" \
		-o "$kitty_dir/tokyonight_storm.conf"
fi

# --- fish ---------------------------------------------------------------
# Runs after linking so fisher sees the stowed config.fish. macOS keeps fish as
# the login shell; Linux uses zsh + starship.
if command -v fish >/dev/null 2>&1; then
	echo "setting up fish plugins..."
	if ! fish -c "type -q fisher" 2>/dev/null; then
		fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
	fi
	for plugin in \
		PatrickF1/fzf.fish \
		jorgebucaran/autopair.fish \
		jorgebucaran/nvm.fish \
		ilancosman/tide@v6 \
		vitallium/tokyonight-fish; do
		fish -c "fisher install $plugin" || echo "  $plugin failed to install"
	done
fi

# --- npm globals --------------------------------------------------------
# macOS-only extras; ccstatusline is installed for every platform by setup.sh.
install_npm_globals carbonyl @mermaid-js/mermaid-cli ccusage

brew cleanup || true
