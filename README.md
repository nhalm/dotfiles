# dotfiles

Personal dotfiles configuration for macOS development environment.

## Setup

```bash
./initial_setup.sh
```

This will:
1. Install all required applications via Homebrew and mise
2. Create symbolic links for all configurations via stow
3. Install Tmux Plugin Manager (TPM)
4. Configure Docker Compose CLI plugin
5. Configure Fish shell with Fisher plugins and Tide prompt
6. Set Fish as the default shell

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
- **Focus Events**: Enabled for proper Neovim file change detection
- **Optimized Escape Time**: Set to 10ms for better Neovim responsiveness
- **Sessionizer** (`Ctrl+b f`): Quick project switching using fzf
  - Searches ~/dev, ~/personal, ~/work, ~/Downloads, ~/Documents
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
  - `git amend` - amend last commit
  - `git ll` - pretty log with file changes
  - `git bclean` - clean merged branches
  - `git fpush` - force push
- **Auto-rebase on pull**: Keeps history linear

## Package Management

### Homebrew
Primary package manager for macOS — CLI tools, Go, and GUI apps via brew/cask

### mise (Runtime Manager)
Language runtimes are managed by [mise](https://mise.jdx.dev/):
- **Node.js**: LTS
- **Python**: 3.13 (uv for package management)
- **Ruby**: 3.4.x
- **Lua**: 5.4 (includes luarocks)
- **Rust**: Latest

## Command Line Tools
- **Search**: ripgrep (rg), fd, fzf for fast file/text searching
- **File Management**: bat (better cat), glow (markdown viewer), tree
- **System Monitoring**: htop
- **JSON/YAML**: jq, yq for processing
- **Git Enhancement**: gh for GitHub CLI operations

## Cloud & DevOps
- **AWS**: AWS CLI v2, aws-vault for credential management
- **Kubernetes**: kubectl, helm
- **Infrastructure**: Terraform
- **Containers**: Docker via Colima (lightweight VM, NFS-backed storage)

## Claude AI Integration
- **Custom Commands** (`~/.claude/commands/`)
- **Custom Scripts** (`~/.claude/scripts/`)
- **Custom Skills** (`~/.claude/skills/`)
- **Personal Configuration**: CLAUDE.md with role context and preferences

## GUI Applications
- **Terminals**: Kitty, Ghostty
- **Editor**: Cursor (AI-enhanced)
- **Browser**: Brave
- **Productivity**: Raycast (launcher), CleanShot (screenshots)
- **Window Management**: AeroSpace (tiling WM), sketchybar (status bar), borders
- **AI Tools**: Claude desktop, ChatGPT, Claude Code CLI

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

## Health Checks

After setup, run `:checkhealth` in Neovim to verify everything is configured correctly.

## Colima (Docker)

Docker runs via Colima with a lightweight vz VM. Docker's data-root is on the NFS share to keep the local disk small.

```bash
colima start --vm-type vz --disk 10 --mount ~:w --mount /Volumes/nfs/dev-storage:w
```

- **VM disk**: 10 GB (minimal — only for OS/runtime)
- **Docker data-root**: `/Volumes/nfs/dev-storage/colima/docker` (images, volumes, build cache all on NFS)
- **Mounts**: Home directory (read/write) + NFS share (read/write)
- **Config**: `~/.colima/default/colima.yaml` — sets `docker.data-root` to the NFS path

Volume backups are stored at `/Volumes/nfs/dev-storage/colima/volume-backups/`.