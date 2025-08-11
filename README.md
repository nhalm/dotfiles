# dotfiles

Personal dotfiles configuration for macOS development environment.

## Setup

```bash
./initial_setup.sh
```

## Shell Configuration

### Fish (Default Shell)
- **Tide prompt**: Informative two-line prompt with git status, command duration, exit codes
- **Fisher plugins**:
  - `PatrickF1/fzf.fish` - Fuzzy search for history (Ctrl+R), files (Ctrl+Alt+F), directories
  - `jorgebucaran/autopair.fish` - Auto-close brackets, quotes, parentheses
  - `jorgebucaran/nvm.fish` - Node version management integrated with fish
- **Key bindings**: 
  - Ctrl+R for fuzzy history search
  - Auto-suggestions from command history
  - Syntax highlighting as you type

### Zsh (Secondary)
- Simplified oh-my-zsh configuration
- Minimal plugins for quick fallback shell

## Development Environment

### Neovim
- **Package Manager**: Lazy.nvim for fast plugin loading
- **LSP Support**: Full language server protocol with Mason for auto-installation
- **Key Features**:
  - Telescope for fuzzy finding files, grep, and more
  - Treesitter for advanced syntax highlighting and text objects
  - Gitsigns for inline git blame and changes
  - Auto-session for workspace persistence
  - Which-key for discoverable keybindings
  - Conform for formatting, nvim-lint for linting
- **Custom Keymaps**: Leader key (space) based navigation

### Tmux
- **TPM (Tmux Plugin Manager)**: Auto-installed for plugin management
- **Sessionizer** (`Ctrl+b f`): Quick project switching using fzf
  - Searches ~/git for projects
  - Creates/attaches to tmux sessions per project
  - Accessible via `tmux-sessionizer` command
- **Custom Keybindings**:
  - Vim-style pane navigation
  - Easy window/pane creation and management

### Git Configuration
- **SSH Commit Signing**: Integrated with 1Password for secure signing
- **SSH URL Rewriting**: Automatically uses SSH for GitHub
- **Global Gitignore**: Excludes macOS system files, IDE configs, logs, env files
- **Useful Aliases**:
  - `git co` - checkout
  - `git cob` - checkout new branch
  - `git publish` - push current branch to origin
  - `git amend` - amend last commit
  - `git ll` - pretty log with file changes
  - `git bclean` - clean merged branches
- **Auto-rebase on pull**: Keeps history linear

## Package Management

### Homebrew
Primary package manager for macOS with all tools installed via brew/cask

### Language-Specific
- **Node.js**: fnm (Fast Node Manager) with nvm.fish integration
- **Python**: pyenv for version management, uv for fast package management
- **Go**: Latest version via Homebrew

## Command Line Tools
- **Search**: ripgrep (rg), fd, fzf for fast file/text searching
- **File Management**: bat (better cat), glow (markdown viewer), tree
- **System Monitoring**: htop, bottom
- **JSON/YAML**: jq, yq for processing
- **HTTP**: httpie for API testing
- **Git Enhancement**: gh for GitHub CLI operations

## Cloud & DevOps
- **AWS**: AWS CLI v2, aws-vault for credential management
- **Kubernetes**: kubectl, helm, k9s for cluster management
- **Infrastructure**: Terraform
- **Containers**: Docker via Colima (lightweight VM)

## Claude AI Integration
- **Custom Agents** (`~/.claude/agents/`):
  - backend-architect, python-dev, golang-dev, sql-pro
  - deployment-engineer, performance-engineer
  - code-reviewer, error-detective
- **Workflows** (`~/.claude/workflows/`):
  - git-workflow, smart-fix, workflow-automate
- **Personal Configuration**: CLAUDE.md with role context and preferences

## GUI Applications
- **Terminals**: Kitty (GPU-accelerated)
- **Editors**: VS Code, Cursor (AI-enhanced)
- **Browser**: Brave
- **Productivity**: Raycast (launcher), CleanShot (screenshots)
- **AI Tools**: Claude desktop, Claude Code CLI

## Directory Structure

```
~/dotfiles/
├── home/              # Symlinked to ~/
│   ├── .config/       # App configs (fish, nvim, etc)
│   ├── .claude/       # Claude AI configuration
│   ├── .gitconfig     # Git configuration
│   ├── .tmux.conf     # Tmux configuration
│   └── tmux/          # TPM plugins
├── bin/               # Scripts in ~/.local/scripts/
└── *.sh              # Setup scripts
```

## SSH Configuration
- ED25519 keys for authentication
- 1Password SSH agent integration
- GitHub SSH URL auto-rewriting