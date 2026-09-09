# Linux-specific interactive setup, sourced by .zshrc.

# 1Password SSH agent (macOS puts this under ~/Library/Group Containers).
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"

# GNU coreutils colour flags; BSD ls on macOS uses -G instead.
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

# matugen renders the prompt from the wallpaper where it runs; elsewhere
# starship falls back to its own defaults.
_starship_generated="${XDG_STATE_HOME:-$HOME/.local/state}/matugen/starship.toml"
[[ -r $_starship_generated ]] && export STARSHIP_CONFIG="$_starship_generated"
unset _starship_generated

# Wayland clipboard, so `pbcopy`-style muscle memory keeps working.
if (( $+commands[wl-copy] )); then
	alias pbcopy='wl-copy'
	alias pbpaste='wl-paste'
fi
