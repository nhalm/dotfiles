#!/usr/bin/env bash

ARM64=false
PLATFORM=""

function _setup_platform() {
	case "$(uname -s)" in
	    Linux*) 
		    PLATFORM="Linux"
		    _linux;;
	    Darwin*) 
		if [[ `uname -m` == 'arm64' ]]; then
			ARM64=true
		fi
		PLATFORM="Mac"
		_mac;;
	    CYGWIN*) echo "cygwin not supported";;
	    MINGW*) echo "MinGw not supported";;
		*)      echo "$(uname -s)  not supported"
	esac
}

function _error_exit() {
	echo ""
	echo "Error while executing ${0##*/}."
	echo "Message: ${1}"
	echo ""

	exit 1
}

function _install_brew() {
	eval "$(/opt/homebrew/bin/brew shellenv)"
	which -s brew
	if [[ $? != 0 ]]; then
		echo "installing brew"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	eval "$(/opt/homebrew/bin/brew shellenv)"
	else
		brew update
	fi
}

function _install_yarn() {
	if [[ $PLATFORM == "Mac" ]]; then
		npm install --global yarn
		export PATH="$(yarn global bin):$PATH"
	fi

	yarn global add @fsouza/prettierd \
		eslint \
		shellcheck \
		neovim \
		intelephense
}

function _install_vs_code_brew() {
	brew install visual-studio-code
	xattr -r -d com.apple.quarantine '/Applications/Visual Studio Code.app'

	code --install-extension ms-vscode.go
	code --install-extension dbaeumer.vscode-eslint
	code --install-extension ms-vscode.vscode-typescript-tslint-plugin
	code --install-extension shinnn.stylelint
	code --install-extension editorconfig.editorconfig
	code --install-extension ivory-lab.jenkinsfile-support
	code --install-extension neilding.language-liquid
	code --install-extension william-voyek.vscode-nginx
	code --install-extension ms-azuretools.vscode-docker
	code --install-extension jdinhlife.gruvbox
}

function _install_docker_brew() {
	brew install docker
	xattr -r -d com.apple.quarantine '/Applications/Docker.app'
	ln -s /Applications/Docker.app/Contents/Resources/bin/docker /usr/local/bin/
}

function _install_python_brew() {
	brew install pyenv

	eval "$(pyenv init --path)"
	local python2_version=$(pyenv install -l | grep --extended-regexp "\s2.*\.[0-9]*$" | tail -n 1)
	local python3_version=$(pyenv install -l | grep --extended-regexp "\s3.*\.[0-9]*$" | tail -n 1)
	pyenv install $python2_version
	pyenv install $python3_version
	pyenv global $python3_version

	python2 -m pip install --upgrade pip
	python3 -m pip install --upgrade pip
	python2 -m pip install --user --upgrade pynvim
	python3 -m pip install --user --upgrade pynvim
}

function _install_ruby_brew() {
	brew install frum
	
	local ruby_version="3.1.0"
	eval "$(frum init)"

	echo "ruby_version=${ruby_version}"
	echo $PATH
	frum install ${ruby_version}
	frum global ${ruby_version}

	if [[ ! -f ~/.gemrc ]]; then
		echo "gem: --no-document" >> ~/.gemrc
	fi

	gem update --system
	gem install rails
	gem install neovim

}

function _install_node_fnm() {
	curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "./.fnm" --skip-shell
}

function _install_nvm() {
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

	nvm install lts/gallium
	corepack enable
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
	version=1.17.8
	curl -OL https://golang.org/dl/go${version}.linux-amd64.tar.gz
	sudo tar -C /usr/local -xvf go${version}.linux-amd64.tar.gz
	rm go${version}.linux-amd64.tar.gz
}

function _install_php_mac() {
	brew install php

	EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
	php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
	ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

	if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
	then
		>&2 echo 'ERROR: Invalid installer checksum'
		rm composer-setup.php
		exit 1
	fi

	FILENAME=composer
	php composer-setup.php --filename=$FILENAME
	RESULT=$?

	if [[ -f ${FILENAME} ]]; then
		sudo cp $FILENAME /usr/local/bin/$FILENAME
		rm $FILENAME
	fi

	rm composer-setup.php
	if [[ $RESULT -ne 0 ]]; then
		echo "php compose fail install"
		exit $RESULT
	fi

	composer global require \
		php-stubs/wordpress-globals \
		php-stubs/wordpress-stubs \
		php-stubs/woocommerce-stubs \
		php-stubs/acf-pro-stubs \
		wpsyntex/polylang-stubs \
		php-stubs/genesis-stubs \
		php-stubs/wp-cli-stubs
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


	brew upgrade

	# get these before python to make the install faster
	brew install openssl readline
	_install_python_brew
	_install_ruby_brew

	brew install openssl
	# Install GNU core utilities
	brew install coreutils

	# Install some other useful utilities like `sponge`.
	brew install moreutils
	# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
	brew install findutils
	# Install GNU `sed`, overwriting the built-in `sed`.
	brew install gnu-sed

#	if ! grep -Fq "${brew_prefix}/bin/bash" /etc/shells; then
#		echo "${brew_prefix}/bin/bash" | sudo tee -a /etc/shells;
#		chsh -s "${brew_prefix}/bin/bash";
#	fi;


	chsh -s /bin/zsh

	if [[ ARM64 == false ]]; then
		brew install adoptopenjdk
	else
		brew install openjdk
	fi

	# Install other useful binaries.
	brew install git \
		ack \
		git-lfs \
		lua \
		p7zip \
		tree \
		tmux \
		openssh \
		grep \
		golang \
		google-chrome \
		dbeaver-community \
		neovim \
		slack \
		iterm2 \
		zoom \
		spotify \
		1password \
		google-drive \
		node \
		slack \
		1password \
		brave-browser \
		evernote \
		aws-vault \
		awscli \
		jq \
		stow \
		webex \
		wget \
		starship

	brew install homebrew/cask-fonts/font-jetbrains-mono \
		homebrew/cask-fonts/font-hack-nerd-font \
		homebrew/cask-fonts/font-dejavu-sans-mono-nerd-font \
		homebrew/cask-fonts/font-fira-code-nerd-font \
		homebrew/cask-fonts/font-inconsolata-nerd-font

	_install_vs_code_brew
	_install_docker_brew
	_install_yarn
	_install_php_mac

	# Specify the preferences directory
	defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "~/.config/iterm2/"
	# Tell iTerm2 to use the custom preferences in the directory
	defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true
	defaults write com.apple.desktopservices DSDontWriteNetworkStores true

	# Remove outdated versions from the cellar.
	brew cleanup	
}

_setup_platform
