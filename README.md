# dotfiles

Personal dotfiles configuration managed with GNU Stow, featuring both **Zsh** and **Fish** shell support.

## Prerequisites

- macOS (Linux support is experimental)
- Git
- Homebrew (will be installed automatically)

## Quick Install

```bash
# Clone to home directory
git clone git@github.com:nhalm/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Install command-line tools (no password prompts)
./default_applications.sh

# Optional: Install GUI applications (may prompt for password)
./gui_applications.sh

# Create symlinks for all configurations
./make_links.sh
```

## What Gets Installed

### Command Line Tools
- **Shells**: Zsh (simplified), Fish with Tide prompt
- **Core utilities**: Git, SSH, ripgrep, fd, fzf, jq, tree, bat, glow
- **Development**: Go, Node.js, Python (pyenv), yarn
- **Editors**: Neovim with full configuration
- **Terminal**: tmux with custom sessionizer
- **Containers**: Docker, Colima

### Fish Shell Features
- **Tide prompt**: Beautiful, informative two-line prompt
- **Plugin manager**: Fisher with essential plugins
- **Auto-completion**: Bracket/quote pairing, fuzzy history search
- **Node management**: Native nvm.fish integration
- **Optimized for AI tools**: Better compatibility with Cursor/Claude

### GUI Applications (Optional)
- **Terminals**: Kitty
- **Editors**: VS Code, Cursor  
- **Browsers**: Brave
- **Productivity**: Raycast, CleanShot, Spotify, Google Drive
- **AI Tools**: Claude, Claude Code, ChatGPT

### Configuration Files
- **Zsh**: Simplified oh-my-zsh setup with essential plugins
- **Fish**: Full configuration with Tide prompt and productivity plugins
- **Git**: Helpful aliases and SSH URL rewriting for GitHub
- **Tmux**: Custom keybindings and sessionizer
- **Neovim**: Complete Lua configuration
- **Claude**: Specialized agents, tools, and workflows

## Shell Usage

### Switch between shells:
```bash
# From zsh to fish
fish

# From fish back to zsh  
exit
```

### Fish shell features:
- **Ctrl+R**: Fuzzy history search
- **Ctrl+Alt+F**: Fuzzy file finder
- **Auto-suggestions**: Type and see suggestions from history
- **Syntax highlighting**: Commands colored as you type

## Installation Scripts

- **`default_applications.sh`**: Core tools, no password required
- **`gui_applications.sh`**: GUI apps, may need admin password
- **`make_links.sh`**: Creates symlinks, handles conflicts gracefully

## Conflict Handling

The installation automatically handles conflicts by:
- Backing up existing configs with `.dotfiles-backup` suffix
- Creating proper symlinks to your dotfiles
- Ignoring backup files in git (`.gitignore` configured)

## Manual Steps After Install

1. **Configure Fish prompt** (optional):
   ```bash
   fish -c "tide configure"
   ```

2. **Configure Claude Code** with your API key

3. **Install additional fonts** if needed for terminal themes

## Directory Structure

- **`home/`** - Files that go directly in `~/` (zsh, git, fish configs)
- **`bin/`** - Scripts that go in `~/.local/scripts/`
- **`nvim/`** - Neovim configuration
- **`claude/`** - Claude agents, tools, and workflows
- **`iterm2/`** - iTerm2 configuration (macOS only)

## Testing Fish Shell

Fish shell is optimized for better AI tool compatibility. Test it with:
- Cursor AI features
- Claude Code interactions
- Command-line AI workflows

The improved shell parsing and cleaner output should resolve interaction issues you may have experienced with zsh.

## Customization

All configurations can be customized by editing files in their respective directories. The setup is idempotent and can be run multiple times safely.
