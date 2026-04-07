# Initialize Homebrew environment
eval "$(/opt/homebrew/bin/brew shellenv)"

# Add local bin to PATH (for Claude Code, etc.)
fish_add_path $HOME/.local/bin

# Add mise shims to PATH so non-interactive processes (e.g. sketchybar) can find mise-managed tools
fish_add_path $HOME/.local/share/mise/shims

# 1Password SSH agent
set -gx SSH_AUTH_SOCK "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# Projects directories for git scanning
set -gx PROJECTS_DIR "$HOME/work:$HOME/personal:$HOME/dev"

if status is-interactive
    # Commands to run in interactive sessions can go here

    # Mise (Python, Ruby, Node.js, Lua, Elixir/Erlang version manager)
    command -q mise; and mise activate fish | source

    # Tmux sessionizer alias
    alias tmf="~/.local/scripts/tmux-sessionizer.sh"

    # Use neovim for vim
    alias vim="nvim"
end
