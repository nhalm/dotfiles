# macOS-specific interactive setup, sourced by .zshrc before compinit.

# Must land on fpath before .zshrc's compinit, which is why the OS fragment
# is sourced above it.
if (( $+commands[brew] )); then
	fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
fi

# BSD ls takes -G for colour; GNU's --color=auto is a parse error here.
alias ls='ls -G'
alias ll='ls -lahG'
alias grep='grep --color=auto'

# matugen renders the prompt from the wallpaper; starship falls back to its
# own defaults until it has.
_starship_generated="${XDG_STATE_HOME:-$HOME/.local/state}/matugen/starship.toml"
[[ -r $_starship_generated ]] && export STARSHIP_CONFIG="$_starship_generated"
unset _starship_generated

