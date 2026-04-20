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

function _install_nix() {
	if command -v nix &> /dev/null; then
		echo "Nix already installed"
		return
	fi
	echo "Installing Nix..."
	curl -L https://nixos.org/nix/install | sh
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

function _install_mise() {
	if ! command -v mise &> /dev/null; then
		echo "Installing mise..."
		brew install mise
	fi

	echo "Installing mise tools from config..."
	mise install
}

function _mac() {
  _install_nix
  _install_brew

#	chsh -s /bin/zsh

	brew upgrade || true

# Install command line tools
	brew install \
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
    tree-sitter-cli \
    imagemagick \
    ghostscript \
    tectonic \
    mermaid-cli \
    1password-cli \
    karabiner-elements

	# Install development tools
	brew install \
		golang \
		yarn \
		openjdk \
		uv \
		docker \
		colima \
		docker-compose \
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
		php \
		composer \
		libyaml \
		readline \
    restic

  # --adopt: prevent errors when app already exists but brew lost track of it (e.g. after OS upgrades)
  brew install --adopt --cask corelocationcli

	# Install fonts
	brew install --cask font-monaspace \
    font-hack-nerd-font

  # for sketchybar
  brew install --cask sf-symbols \
    font-sf-mono \
    font-sf-pro \
    font-victor-mono-nerd-font \
    font-sketchybar-app-font

	# Optional language tools (uncomment if needed)
	# brew install --force \
	#	rust \           # Rust toolchain (includes cargo)
	#	tree-sitter \    # Tree-sitter CLI for grammar compilation
	#	julia            # Julia language

	# GUI applications moved to gui_applications.sh to avoid password prompts 

	_install_mise

	# Install/update carbonyl (terminal browser) via npm
	if command -v carbonyl &> /dev/null; then
		npm update -g carbonyl
	else
		npm install -g carbonyl
	fi

	# Install claude-code via npm
	# if ! command -v claude &> /dev/null; then
	# 	npm install -g @anthropic-ai/claude-code
	# fi
  curl -fsSL https://claude.ai/install.sh | bash

	# Specify the preferences directory

	# Remove outdated versions from the cellar.
	brew cleanup	
}

_setup_platform
