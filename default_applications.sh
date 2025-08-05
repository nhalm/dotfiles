#!/usr/bin/env bash
set -euo pipefail

ARM64=false
PLATFORM=""

function _setup_platform() {
	case "$(uname -s)" in
	    Linux*) 
		    PLATFORM="Linux"
		    _linux;;
	    Darwin*) 
				if [[ $(uname -m) == 'arm64' ]]; then
			ARM64=true
		fi
		PLATFORM="Mac"
		_mac;;
	    CYGWIN*) echo "cygwin not supported";;
	    MINGW*) echo "MinGw not supported";;
		*)      echo "$(uname -s)  not supported"
	esac

  #_install_oh_my_zsh
}

function _error_exit() {
	echo ""
	echo "Error while executing ${0##*/}."
	echo "Message: ${1}"
	echo ""

	exit 1
}

function _install_oh_my_zsh() {
  sh -c "$(curl -fsSL https://install.ohmyz.sh)"
}

function _install_brew() {
	eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
	if ! command -v brew &> /dev/null; then
		echo "Installing brew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		eval "$(/opt/homebrew/bin/brew shellenv)"
	else
		echo "Brew already installed, updating..."
		brew update
	fi
}

function _install_yarn() {
	if [[ $PLATFORM == "Mac" ]]; then
		# Skip npm yarn install since we install via Homebrew
		if command -v yarn &> /dev/null; then
			yarn_path="$(yarn global bin)"
			export PATH=$yarn_path:$PATH
		fi
	fi

	yarn global add @fsouza/prettierd \
		eslint \
		shellcheck \
		neovim
}

function _setup_fish() {
	if command -v fish &> /dev/null; then
		echo "Setting up fish shell plugins..."
		# Install fisher plugin manager
		fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
		# Install plugins from fish_plugins file
		fish -c "fisher update"
		echo "Fish shell setup complete"
	else
		echo "Fish shell not found, skipping fish setup"
	fi
}

function _install_python_brew() {
	if ! command -v pyenv &> /dev/null; then
		echo "Installing pyenv..."
		brew install pyenv
	fi

	eval "$(pyenv init --path)"
	python2_version=$(pyenv install -l | grep --extended-regexp "\s2.*\.[0-9]*$" | tail -n 1 | xargs)
	python3_version=$(pyenv install -l | grep --extended-regexp "\s3.*\.[0-9]*$" | tail -n 1 | xargs)

	if ! pyenv versions | grep -q "$python2_version"; then
		echo "Installing Python $python2_version..."
		pyenv install "$python2_version"
	fi
	
	if ! pyenv versions | grep -q "$python3_version"; then
		echo "Installing Python $python3_version..."
		pyenv install "$python3_version"
	fi
	
	pyenv global "$python3_version"

	python2 -m pip install --upgrade pip
	python3 -m pip install --upgrade pip
	python2 -m pip install --user --upgrade pynvim
	python3 -m pip install --user --upgrade pynvim
}


function _install_node_fnm() {
	curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "./.fnm" --skip-shell
}

function _install_nvm() {
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

	nvm install lts/iron
}

function _add_1password_apt() {
	# Add the key for the 1Password apt repository
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
	# Add the 1Password apt repository
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list

	# Add the debsig-verify policy
	sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
	curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
	sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
}

function _install_golang() {
	version=1.21.5
	curl -OL https://golang.org/dl/go${version}.linux-amd64.tar.gz
	sudo tar -C /usr/local -xvf go${version}.linux-amd64.tar.gz
	rm go${version}.linux-amd64.tar.gz
}

function _linux() {
	sudo add-apt-repository ppa:neovim-ppa/unstable
	_add_1password_apt

	sudo apt update \
		&& sudo apt upgrade -y \
		&& sudo apt install -y \
			git \
			lua5.3 \
			neovim \
			tree \
			tmux \
			jq \
			stow \
			curl \
			ca-certificates \
			wget \
			zsh \
			1password \
			fonts-firacode

	

	curl -fsSL https://starship.rs/install.sh | sh
	chsh -s /usr/bin/zsh root

	_install_golang
	_install_nvm	
	_install_yarn
}

function _mac() {
  _install_brew

#	chsh -s /bin/zsh

	brew upgrade

# Install command line tools
	brew install --force \
		git \
		git-lfs \
		openssh \
		openssl \
		readline \
		moreutils \
		gnu-sed \
		coreutils \
		grep \
		wget \
		jq \
		stow \
		ack \
		ripgrep \
		fd \
		fzf \
		tree \
		p7zip \
		tmux \
		neovim \
		glow \
		bat \
		fish

	# Install development tools
	brew install --force \
		golang \
		node \
		yarn \
		openjdk \
		uv \
		docker \
		colima \
		aws-vault \
		awscli

	# GUI applications moved to gui_applications.sh to avoid password prompts 

	
	_install_yarn
	_setup_fish

	# Specify the preferences directory

	# Remove outdated versions from the cellar.
	brew cleanup	
}

_setup_platform
