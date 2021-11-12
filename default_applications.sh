#!/usr/bin/env bash

platform=""

function _setup_platform() {
	local unameOut="$(uname -s)"

	case "${unameOut}" in
	    Linux*)     platform=Linux
		    	_linux
			;;
	    Darwin*)    platform=Mac
		    	_mac
			;;
	    CYGWIN*)    platform=Cygwin;;
	    MINGW*)     platform=MinGw;;
	    *)          platform="UNKNOWN:${unameOut}"
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
	which -s brew
	if [[ $? != 0 ]]; then
		echo "installing brew"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	else
		brew update
	fi
}

function _install_yarn() {
	npm install -g yarn
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

function _mac() {
	_install_brew

	local brew_prefix=$(brew --prefix)

	echo "Upgrading Brew"
	brew upgrade

	brew install openssl@1.1
	# Install GNU core utilities
	brew install coreutils

	# Install some other useful utilities like `sponge`.
	brew install moreutils
	# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
	brew install findutils
	# Install GNU `sed`, overwriting the built-in `sed`.
	brew install gnu-sed
	# Install a modern version of Bash.
	brew install bash \
		bash-completion

	# Switch to using brew-installed bash as default shell
	if ! fgrep -q "${brew_prefix}/bin/bash" /etc/shells; then
		echo "${brew_prefix}/bin/bash" | sudo tee -a /etc/shells;
		chsh -s "${brew_prefix}/bin/bash";
	fi;


	# Install other useful binaries.
	# I would do a single command but it seems that 
	# brew doesn't appreciate many applications at once. 🤷
	brew install neovim
	brew install git
	brew install ack
	brew install git-lfs
	brew install gs
	brew install lua
	brew install lynx
	brew install p7zip
	brew install pigz
	brew install pv
	brew install rename
	brew install rlwrap
	brew install ssh-copy-id
	brew install tree
	brew install vbindiff
	brew install zopfli
	brew install tmux
	brew install openssh
	brew install grep
	brew install golang
	brew install adoptopenjdk
	brew install google-chrome
	brew install brew install
	brew install dbeaver-community
	brew install slack
	brew install iterm2
	brew install zoom
	brew install spotify
	brew install 1password
	brew install dialpad
	brew install openvpn-connect
	brew install ngrok
	brew install adobe-acrobat-reader
	brew install google-drive
	brew install node
	brew install slack
	brew install 1password
	brew install brave-browser
	brew install evernote
	brew install aws-vault
	brew install awscli
	brew install jq
	brew install stow
	brew install webex

	brew install homebrew/cask-fonts/font-jetbrains-mono
	brew install homebrew/cask-fonts/font-hack-nerd-font
	brew install homebrew/cask-fonts/font-dejavu-sans-mono-nerd-font
	brew install homebrew/cask-fonts/font-fira-code-nerd-font
	brew install homebrew/cask-fonts/font-inconsolata-nerd-font

	_install_vs_code_brew
	_install_docker_brew
	_install_yarn

	# Remove outdated versions from the cellar.
	brew cleanup	

}

_setup_platform
