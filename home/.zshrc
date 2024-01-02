#!/usr/bin/env bash
## Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh


case $- in
    *i*) ;;
      *) return;;
esac

function _get_platform()
{
	local unameOut="$(uname -s)"
	local maching="UNKNOWN"

	case "${unameOut}" in
	    Linux*)     machine=Linux;;
	    Darwin*)    machine=Mac;;
	    CYGWIN*)    machine=Cygwin;;
	    MINGW*)     machine=MinGw;;
	    *)          machine="UNKNOWN:${unameOut}"
	esac
	echo ${machine}
}


PLATFORM=$(_get_platform)

# handle setting up Golang
GOPATH=$HOME/go
export GOPATH=$GOPATH
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$GOPATH/bin

if [ ! -d $GOPATH ]; then
	mkdir -p $GOPATH/src
	mkdir -p $GOPATH/bin
fi

export EDITOR='nvim'
export VISUAL='nvim'

if [[ ${PLATFORM} == "Linux" ]]; then
	# export PATH=$HOME/.fnm:$PATH
fi

# platform specific setups
if [[ ${PLATFORM} == "Mac" ]]; then
	# handle adding brew to path
	eval "$(/opt/homebrew/bin/brew shellenv)"

	#OPENSSL_VERSION="1.1"
	##For compilers to find things you may need to set:
	#export LDFLAGS="-L/usr/local/opt/gettext/lib -L/usr/local/opt/openssl@${OPENSSL_VERSION}/lib"
	#export CPPFLAGS="-I/usr/local/opt/gettext/include -I/usr/local/opt/openssl${OPENSSL_VERSION}/include"

	## Ruby stuff
	# export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
	# export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"
	# export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"
	# export PKG_CONFIG_PATH="/opt/homebrew/opt/ruby/lib/pkgconfig"


	# if we are originating from a tmux session 
	# we do not need to rebuild the path.
	if [ -z "${TMUX+x}" ]; then
		export PATH="$PATH:/usr/local/opt/mysql@5.6/bin"
		export PATH="$PATH:/usr/local/opt/libpq/bin"
		export PATH="$PATH:$HOME/.cargo/bin"
	fi

	export PATH="$(yarn global bin):$PATH"
	# https://egeek.me/2020/04/18/enabling-locate-on-osx/
	if which glocate > /dev/null; then
		alias locate="glocate -d $HOME/locatedb"
		[[ -f "$HOME/locatedb" ]] && export LOCATE_PATH="$HOME/locatedb"
	fi
	alias loaddb="gupdatedb --localpaths=$HOME --prunepaths=/Volumes --output=$HOME/locatedb"

	eval "$(pyenv init --path)"
	eval "$(frum init)"
fi

autoload -Uz compinit && compinit
MY_SSH_AUTH_SOCK=${HOME}/.ssh/ssh_auth_sock

__start_ssh_agent() {
	eval $(ssh-agent) > /dev/null
	ln -sf ${SSH_AUTH_SOCK} ${MY_SSH_AUTH_SOCK}
	export SSH_AUTH_SOCK=${MY_SSH_AUTH_SOCK}
	ssh-add > /dev/null || ssh-add
}

if [  ! -S ${MY_SSH_AUTH_SOCK} ]; then
	__start_ssh_agent
fi
export SSH_AUTH_SOCK=${MY_SSH_AUTH_SOCK}

if type nvim > /dev/null 2>&1; then
	alias vi='nvim'
	alias vim='nvim'
fi

if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

# if [[ ${PLATFORM} == "Mac" ]]; then
#	eval "$(starship init zsh)"
# fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
