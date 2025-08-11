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

# Setup fish after stow has created symlinks
if command -v fish &> /dev/null; then
    echo "setting up fish shell plugins..."
    # Install fisher plugin manager if not already installed
    if ! fish -c "type -q fisher" 2>/dev/null; then
        echo "installing Fisher plugin manager..."
        fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
    fi
    # Install plugins from fish_plugins file if it exists
    if [ -f "$HOME/.config/fish/fish_plugins" ]; then
        echo "installing/updating fish plugins..."
        fish -c "fisher update"
    fi
    echo "fish shell setup complete"
    
    # Set fish as default shell
    echo "setting fish as default shell..."
    fish_path=$(which fish)
    if ! grep -q "$fish_path" /etc/shells; then
        echo "adding fish to /etc/shells (may require password)..."
        echo "$fish_path" | sudo tee -a /etc/shells
    fi
    chsh -s "$fish_path"
    echo "fish is now the default shell"
else
    echo "fish not installed, skipping fish setup"
fi

# if [[ ${platform} == "Mac" ]]; then
# 	echo "setting up nfs..."
# 	$cdir/darwin_nfs.sh
# 	echo "finished setting up nfs"
# 	echo ""
# fi

# echo "configuring fonts..."
# $cdir/fonts/install.sh
# echo "finished configuring fonts"
# echo
