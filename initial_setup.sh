#!/usr/bin/env bash
set -euo pipefail

cdir=$(pwd)

platform=""

function _setup_platform() {
	local unameOut="$(uname -s)"

	echo $unameOut
	case "${unameOut}" in
	    Linux*)     platform=Linux
			;;
	    Darwin)    platform="Mac"
			;;
	    CYGWIN*)    platform=Cygwin;;
	    MINGW*)     platform=MinGw;;
	    *)          platform="UNKNOWN:${unameOut}"
	esac
}

_setup_platform

echo $cdir

echo "installing default applications..."
$cdir/default_applications.sh
echo "finished installs"

echo "setting symlinks..."
$cdir/make_links.sh
echo "finished setting symlinks"
echo

echo "installing tmux plugin manager..."
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    echo "TPM installed successfully"
else
    echo "TPM already installed"
fi
echo

echo "downloading kitty tokyonight-moon theme..."
kitty_config_dir="$HOME/.config/kitty"
if [ ! -f "$kitty_config_dir/tokyonight_moon.conf" ]; then
    mkdir -p "$kitty_config_dir"
    curl -fsSL "https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/kitty/tokyonight_moon.conf" -o "$kitty_config_dir/tokyonight_moon.conf"
    echo "kitty tokyonight-moon theme downloaded successfully"
else
    echo "kitty tokyonight-moon theme already exists"
fi
echo

# Setup Python environment for Neovim
echo "setting up Python environment for Neovim..."
if command -v pyenv &> /dev/null && pyenv commands | grep -q virtualenv; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    
    # Create dedicated virtualenv for Neovim if it doesn't exist
    if ! pyenv versions --bare | grep -q "^neovim$"; then
        python3_version=$(pyenv install -l | grep --extended-regexp "^\s+3\.[0-9]+\.[0-9]+$" | tail -n 1 | xargs)
        echo "Creating Neovim Python environment with Python ${python3_version}..."
        
        # Install Python version if not already installed
        if ! pyenv versions --bare | grep -q "^${python3_version}$"; then
            pyenv install -s "$python3_version"
        fi
        
        # Create virtualenv and install pynvim
        pyenv virtualenv "$python3_version" neovim
        pyenv shell neovim
        pip install --upgrade pip pynvim
        pyenv shell --unset
        echo "Neovim Python environment created"
    else
        echo "Neovim Python environment already exists"
    fi
else
    echo "pyenv-virtualenv not found, skipping Neovim Python setup"
fi
echo

# Setup fish after stow has created symlinks
if command -v fish &> /dev/null; then
    echo "setting up fish shell plugins..."
    # Install fisher plugin manager if not already installed
    if ! fish -c "type -q fisher" 2>/dev/null; then
        echo "installing Fisher plugin manager..."
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
    fi
    # Install fish plugins individually
    echo "installing fish plugins..."
    fish -c "fisher install PatrickF1/fzf.fish" || echo "fzf.fish failed to install"
    fish -c "fisher install jorgebucaran/autopair.fish" || echo "autopair.fish failed to install"
    fish -c "fisher install jorgebucaran/nvm.fish" || echo "nvm.fish failed to install"
    fish -c "fisher install ilancosman/tide@v6" || echo "tide failed to install"
    fish -c "fisher install vitallium/tokyonight-fish" || echo "tokyonight-fish failed to install"
    echo "fish shell setup complete"
    
    # Set fish as default shell if not already set
    fish_path=$(which fish)
    current_shell=$(dscl . -read /Users/$(whoami) UserShell | awk '{print $2}')
    
    if [ "$current_shell" = "$fish_path" ]; then
        echo "fish is already the default shell"
    else
        echo "setting fish as default shell..."
        if ! grep -q "$fish_path" /etc/shells; then
            echo "adding fish to /etc/shells (may require password)..."
            echo "$fish_path" | sudo tee -a /etc/shells
        fi
        chsh -s "$fish_path"
        echo "fish is now the default shell"
    fi
else
    echo "fish not installed, skipping fish setup"
fi

echo "Neovim plugins can be installed manually by running ':Lazy sync' in nvim"
echo

echo "Setup complete! 🎉"
echo "Please restart your terminal and run 'nvim' then ':checkhealth' to verify everything is working correctly."
