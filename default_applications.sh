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


# Fish setup moved to initial_setup.sh to run after stow creates symlinks

function _install_python_brew() {
	# Install Python with uv (fast, pre-built binaries)
	if command -v uv &> /dev/null; then
		uv python install 3.13
	fi

	# Install pyenv and pyenv-virtualenv for Python version management
	if ! command -v pyenv &> /dev/null; then
		brew install pyenv pyenv-virtualenv
	else
		# Ensure pyenv-virtualenv is installed even if pyenv already exists
		brew list pyenv-virtualenv &>/dev/null || brew install pyenv-virtualenv
	fi

	eval "$(pyenv init --path)"
	python3_version=$(pyenv install -l | grep --extended-regexp "\s3.*\.[0-9]*$" | tail -n 1 | xargs)

	if ! pyenv versions --bare | grep -q "^${python3_version}$"; then
		pyenv install -s "$python3_version"
	fi
	
	pyenv global "$python3_version"
}




function _mac() {
  _install_brew

#	chsh -s /bin/zsh

	brew upgrade

# Install command line tools
	brew install --force \
    bash \
		git \
		git-lfs \
		openssh \
		openssl \
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
		fish \
    1password-cli

	# Install development tools
	brew install --force \
		golang \
		fnm \
		yarn \
		openjdk \
		uv \
		docker \
		colima \
		aws-vault \
		awscli \
		autoconf \
		dos2unix \
		gh \
		helm \
		htop \
		kubernetes-cli \
		terraform \
		yq \
    claude-code

	# Disable Claude Code auto-updater (use brew for updates instead)
	claude config set -g autoUpdates false 2>/dev/null || true

	# Install fonts
	brew install --cask font-monaspace

	# Optional language tools (uncomment if needed)
	# brew install --force \
	#	rust \           # Rust toolchain (includes cargo)
	#	tree-sitter \    # Tree-sitter CLI for grammar compilation
	#	php \            # PHP language
	#	composer \       # PHP package manager
	#	julia            # Julia language

	# GUI applications moved to gui_applications.sh to avoid password prompts 

	_install_python_brew

	# Specify the preferences directory

	# Remove outdated versions from the cellar.
	brew cleanup	
}

_setup_platform
