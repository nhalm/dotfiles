# dotfiles

Personal dotfiles configuration managed with GNU Stow.

## Prerequisites

- macOS (Linux support is experimental)
- Git
- Zsh (default on modern macOS)

## Quick Install

```bash
# Clone to home directory
git clone git@github.com:nhalm/dotfiles.git ~/dotfiles
cd ~/dotfiles
./initial_setup.sh
```

## What Gets Installed

### Command Line Tools
- Git, SSH, core utilities
- Development tools: ripgrep, fd, fzf, jq, tree
- Text editors: neovim with full configuration
- Terminal: tmux with custom sessionizer

### Development Environment  
- Go, Node.js, Python (via pyenv)
- Docker, AWS CLI, various cloud tools
- Package managers: brew, uv

### GUI Applications
- Terminals: Kitty
- Editors: VS Code, Cursor
- Browsers: Brave
- Productivity: Raycast, CleanShot
- AI Tools: Claude, Claude Code, ChatGPT

### Configuration Files
- Zsh with oh-my-zsh and powerlevel10k theme
- Tmux with custom keybindings
- Git with helpful aliases
- Neovim with full Lua configuration
- Global gitignore
- Claude AI agent configurations

## Manual Steps After Install

1. Configure 1Password and sign in to sync SSH keys
2. Run `p10k configure` to set up your prompt theme
3. Install fonts if needed for terminal themes
4. Configure Claude Code with your API key

## Directory Structure

- `home/` - Files that go directly in `~/`
- `bin/` - Scripts that go in `~/.local/scripts/`
- `nvim/` - Neovim configuration
- `claude/` - Claude AI configurations (synced via stow)

## Customization

Most configurations can be customized by editing files in the respective directories before running stow. The setup is designed to be idempotent - you can run it multiple times safely.
