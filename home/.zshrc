#!/usr/bin/env bash

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

# handle adding brew to path
eval "$(/opt/homebrew/bin/brew shellenv)"

# add yarn to path
export PATH="$(yarn global bin):$PATH"

# handle setting up Golang
GOPATH=$HOME/go
export GOPATH=$GOPATH
export PATH=$PATH:$GOPATH/bin

if [ ! -d $GOPATH ]; then
	mkdir -p $GOPATH/src
	mkdir -p $GOPATH/bin
fi

export EDITOR='nvim'
export VISUAL='nvim'

# platform specific setups
if [[ ${PLATFORM} == "Mac" ]]; then
	OPENSSL_VERSION="1.1"
	#For compilers to find things you may need to set:
	export LDFLAGS="-L/usr/local/opt/gettext/lib -L/usr/local/opt/openssl@${OPENSSL_VERSION}/lib"
	export CPPFLAGS="-I/usr/local/opt/gettext/include -I/usr/local/opt/openssl${OPENSSL_VERSION}/include"

	# if we are originating from a tmux session 
	# we do not need to rebuild the path.
	if [ -z "${TMUX+x}" ]; then
		export PATH="$PATH:/usr/local/opt/mysql@5.6/bin"
		export PATH="$PATH:/usr/local/opt/libpq/bin"
		export PATH="$PATH:$HOME/.cargo/bin"
	fi
fi

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

eval "$(starship init zsh)"
