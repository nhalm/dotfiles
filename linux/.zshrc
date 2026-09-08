# Interactive zsh. Machine- and OS-specific pieces are sourced, not inlined:
#   ~/.config/zsh/os.zsh     from the OS stow package (tracked)
#   ~/.config/zsh/local.zsh  per-machine, gitignored

setopt EXTENDED_GLOB

# --- history ------------------------------------------------------------
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
mkdir -p "${HISTFILE:h}"
setopt HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt SHARE_HISTORY INC_APPEND_HISTORY EXTENDED_HISTORY
setopt HIST_VERIFY

# --- options ------------------------------------------------------------
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP
setopt NO_FLOW_CONTROL          # free up ctrl-s / ctrl-q

# --- completion ---------------------------------------------------------
autoload -Uz compinit
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${_zcompdump:h}"
# Rebuild the dump at most once a day; -C skips the (slow) security check.
if [[ -n ${_zcompdump}(#qNmh-24) ]]; then
	compinit -C -d "$_zcompdump"
else
	compinit -d "$_zcompdump"
fi
unset _zcompdump

zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# --- keys ---------------------------------------------------------------
bindkey -e                                    # emacs bindings; fzf rebinds ^R below
bindkey '^[[1;5C' forward-word                # ctrl-right
bindkey '^[[1;5D' backward-word               # ctrl-left
bindkey '^[[3~'   delete-char
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line

# Up/down search history against what is already typed.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# --- OS fragment --------------------------------------------------------
[[ -r ~/.config/zsh/os.zsh ]] && source ~/.config/zsh/os.zsh

# --- aliases ------------------------------------------------------------
alias vi='nvim'
alias vim='nvim'
alias lg='lazygit'

# --- plugins ------------------------------------------------------------
# Cloned by lib/common.sh rather than packaged, so the set is identical
# on every machine. Order matters: syntax highlighting goes last.
_zplugdir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
if [[ -d $_zplugdir/zsh-completions/src ]]; then
	fpath=("$_zplugdir/zsh-completions/src" $fpath)
fi
[[ -r $_zplugdir/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
	source "$_zplugdir/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -r $_zplugdir/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]] &&
	source "$_zplugdir/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
unset _zplugdir

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f89'

# --- tools --------------------------------------------------------------
# mise resolves the correct runtime version per directory; the shims added in
# .zprofile only exist for processes that never source a shell rc.
(( $+commands[mise] ))     && eval "$(mise activate zsh)"
(( $+commands[zoxide] ))   && eval "$(zoxide init zsh --cmd cd)"
(( $+commands[starship] )) && eval "$(starship init zsh)"
(( $+commands[fzf] ))      && source <(fzf --zsh)

# --- machine-local ------------------------------------------------------
[[ -r ~/.config/zsh/local.zsh ]] && source ~/.config/zsh/local.zsh
