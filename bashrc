#!/usr/bin/env bash

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
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
export PATH=$PATH:$GOPATH/bin

if [ ! -d $GOPATH ]; then
	mkdir -p $GOPATH/src
	mkdir -p $GOPATH/bin
fi

export EDITOR='nvim'
export VISUAL='nvim'

# platform specific setups
if [ ${PLATFORM} == "Mac" ]; then
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
 
	if [[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]]; then
		source "/usr/local/etc/profile.d/bash_completion.sh"
	fi
fi

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi
NORMAL="\[\033[00m\]"
BLUE="\[\033[01;34m\]"
YELLOW="\[\033[1;33m\]"
GREEN="\[\033[1;32m\]"

if [ "$color_prompt" = yes ]; then
	PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;36m\]\w\[\033[00m\]:${YELLOW}\$(__kube_ps1)${NORMAL}\n\$ "

else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    	
elif [ ${PLATFORM} == "Mac" ]; then
    alias ls='ls -G'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi


# colored GCC warnings and errors
# export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
#alias ll='ls -l'
#alias la='ls -A'
#alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
NORMAL="\[\033[00m\]"
BLUE="\[\033[01;34m\]"
YELLOW="\[\e[1;33m\]"
GREEN="\[\e[1;32m\]"

# enable kubectl autocompletion
# if installed
if [[ $(which kubectl 2>&1) ]]; then
	source <(kubectl completion bash)
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

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

eval "$(starship init bash)"
