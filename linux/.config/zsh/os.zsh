# Linux-specific interactive setup, sourced by .zshrc.

# 1Password SSH agent (macOS puts this under ~/Library/Group Containers).
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"

# GNU coreutils colour flags; BSD ls on macOS uses -G instead.
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

# Wayland clipboard, so `pbcopy`-style muscle memory keeps working.
if (( $+commands[wl-copy] )); then
	alias pbcopy='wl-copy'
	alias pbpaste='wl-paste'
fi
