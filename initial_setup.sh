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
