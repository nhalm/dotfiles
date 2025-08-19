# Pyenv setup
set -gx PYENV_ROOT $HOME/.pyenv
set -gx PATH $PYENV_ROOT/bin $PATH
status is-command-substitution; or pyenv init --path | source

if status is-interactive
    # Commands to run in interactive sessions can go here
    
    
    # Tmux sessionizer alias
    alias tmf="~/.local/scripts/tmux-sessionizer.sh"
    
    # Use neovim for vim
    alias vim="nvim"
    
    # Pyenv interactive setup
    pyenv init - | source
end
