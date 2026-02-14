# Initialize Homebrew environment
eval "$(/opt/homebrew/bin/brew shellenv)"

# Add local bin to PATH (for Claude Code, etc.)
fish_add_path $HOME/.local/bin

# Projects directories for git scanning
set -gx PROJECTS_DIR "$HOME/work:$HOME/personal:$HOME/dev"

# Pyenv setup
set -gx PYENV_ROOT $HOME/.pyenv
set -gx PATH $PYENV_ROOT/bin $PATH
status is-command-substitution; or pyenv init --path | source

if status is-interactive
    # Commands to run in interactive sessions can go here
    
    # Ruby setup (rv)
    rv shell init fish | source
    
    # Node.js setup (fnm)
    fnm env --use-on-cd | source
    
    # Tmux sessionizer alias
    alias tmf="~/.local/scripts/tmux-sessionizer.sh"
    
    # Use neovim for vim
    alias vim="nvim"
    
    # Pyenv interactive setup
    pyenv init - | source
end
