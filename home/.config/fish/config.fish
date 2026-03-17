# Initialize Homebrew environment
eval "$(/opt/homebrew/bin/brew shellenv)"

# Add local bin to PATH (for Claude Code, etc.)
fish_add_path $HOME/.local/bin

# 1Password SSH agent
set -gx SSH_AUTH_SOCK "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Projects directories for git scanning
set -gx PROJECTS_DIR "$HOME/work:$HOME/personal:$HOME/dev"

# Pyenv setup
if test -d $HOME/.pyenv
    set -gx PYENV_ROOT $HOME/.pyenv
    set -gx PATH $PYENV_ROOT/bin $PATH
    status is-command-substitution; or pyenv init --path | source
end

if status is-interactive
    # Commands to run in interactive sessions can go here
    
    # Ruby setup (rv)
    command -q rv; and rv shell init fish | source
    
    # Node.js setup (fnm)
    command -q fnm; and fnm env --use-on-cd | source

    # Mise (Elixir/Erlang version manager)
    command -q mise; and mise activate fish | source
    
    # Tmux sessionizer alias
    alias tmf="~/.local/scripts/tmux-sessionizer.sh"
    
    # Use neovim for vim
    alias vim="nvim"
    
    # Pyenv interactive setup
    command -q pyenv; and pyenv init - | source
end
