# Keybinding Cheatsheet

Single-source reference for tmux, aerospace, and nvim. For Go-60-specific
ergonomics (HRMs, thumb cluster, layers), see
[`zmk-config/KEYMAP.md`](https://github.com/nhalm/zmk-config/blob/main/KEYMAP.md).

## Layer model — who owns what

```
Keyboard / Karabiner ── ZMK / caps-as-hyper ────┐
                                                 ▼
                          Aerospace  ── windows + workspaces (alt-*, hyper-*)
                                                 ▼
                          Tmux       ── panes + sessions (C-Space prefix, C-HJKL)
                                                 ▼
                          Neovim     ── splits + buffers (<leader>, C-HJKL)
```

`Hyper` = `Ctrl+Alt+Cmd`. On Go 60 hold the HYP thumb; on laptop hold `caps`.
`C-HJKL` is shared by tmux and nvim — vim-tmux-navigator routes to whichever
context is active.

---

## Aerospace

### Workspaces

| Workspace | Auto-assigned apps |
|-----------|--------------------|
| **Q** | Ghostty, Claude desktop, ChatGPT |
| **W** | Vivaldi, Notion |
| **E** | Messages |
| **R** | 1Password, Zoom, Spotify, Wispr Flow, Screen Sharing (all floating) |
| **T** | Safari |

### Main mode

| Chord | Action |
|-------|--------|
| `Hyper + Q/W/E/R/T` | Jump to workspace |
| `Hyper + Shift + Q/W/E/R/T` | Move focused window to workspace |
| `Hyper + Tab` | Workspace back-and-forth |
| `Hyper + Shift + Tab` | Move workspace to next monitor (laptop) |
| `Hyper + M` | Move workspace to next monitor (Go 60) |
| `Alt + H/J/K/L` | Focus window left/down/up/right |
| `Hyper + H/J/K/L` | Move window left/down/up/right within workspace |
| `Alt + -` / `Alt + =` | Resize window smaller / larger |
| `Alt + ,` / `Alt + /` | Layout accordion / tiles |
| `Alt + ;` | Enter service mode |

### Service mode (after `Alt + ;`)

| Key | Action |
|-----|--------|
| `H/J/K/L` | Join window with neighbor (then exits to main) |
| `R` | Reset/flatten workspace tree |
| `F` | Toggle floating ↔ tiling layout |
| `Backspace` | Close all windows but current |
| `Up` / `Down` | Volume up / down |
| `Esc` | Reload config and exit to main |

---

## Tmux

**Prefix:** `Ctrl+Space`. All "prefix-then-X" bindings below assume that prefix.

### Pane navigation (no prefix needed)

`vim-tmux-navigator` routes these between vim splits and tmux panes
automatically.

| Chord | Action |
|-------|--------|
| `Ctrl+H` | Pane left (or vim split left if vim is active) |
| `Ctrl+J` | Pane down / vim split down |
| `Ctrl+K` | Pane up / vim split up |
| `Ctrl+L` | Pane right / vim split right |

### Pane management (with prefix)

| Chord | Action |
|-------|--------|
| `prefix \` | Split vertically |
| `prefix -` | Split horizontally |
| `prefix h/j/k/l` | Switch pane (fallback — same as bare `C-HJKL`) |
| `prefix H/J/K/L` | Resize pane left/down/up/right by 5 (repeatable, `-r`) |

### Sessions / windows

| Chord | Action |
|-------|--------|
| `prefix f` | Open tmux-sessionizer popup |
| `prefix b` | Switch to previous session |
| `prefix r` | Reload `~/.tmux.conf` |

---

## Neovim

**Leader:** `Space` (right thumb). All `<leader>X` bindings below.

### General editing

| Mode | Keys | Action |
|------|------|--------|
| i | `jk` | Exit insert mode |
| n | `<leader>nh` | Clear search highlight |
| n | `<leader>+` / `<leader>-` | Increment / decrement number under cursor |

### Window / split management

| Mode | Keys | Action |
|------|------|--------|
| n | `<leader>sv` | Split vertical |
| n | `<leader>sh` | Split horizontal |
| n | `<leader>se` | Equalize splits |
| n | `<leader>sx` | Close current split |
| n | `<leader>s+` / `<leader>s-` | Increase / decrease height |
| n | `<leader>s>` / `<leader>s<` | Increase / decrease width |
| n | `<leader>sm` | Maximize / restore split |
| n | `<C-h/j/k/l>` | Navigate split (or tmux pane via vim-tmux-navigator) |
| n | `<C-\>` | Navigate to previous split |

### Buffers, tabs, sessions

| Mode | Keys | Action |
|------|------|--------|
| n | `<leader>to` / `<leader>tx` | Open / close tab |
| n | `<leader>tn` / `<leader>tp` | Next / previous tab |
| n | `<leader>tf` | Open current buffer in new tab |
| n | `<leader>fb` | Find buffer (snacks picker) |
| n | `<leader>bd` | Dashboard |
| n | `<leader>wr` / `<leader>ws` | Restore / save session for cwd |

### File / project navigation (snacks)

| Mode | Keys | Action |
|------|------|--------|
| n | `<leader>e` | Toggle explorer |
| n | `<leader>ff` | Find files |
| n | `<leader>fg` | Live grep |
| n | `<leader>fr` | Recent files |
| n | `<leader>fh` | Help pages |
| n | `<leader>fk` | Find keymaps |
| n | `<leader>fc` | Colorschemes |

### LSP / diagnostics

| Mode | Keys | Action |
|------|------|--------|
| n | `gd` | Definitions |
| n | `gD` | Declaration |
| n | `gR` | References |
| n | `gi` | Implementations |
| n | `gt` | Type definitions |
| n | `K` | Hover docs |
| n, v | `<leader>ca` | Code actions |
| n | `<leader>rn` | Rename symbol |
| n | `<leader>D` / `<leader>d` | Buffer / line diagnostics |
| n | `[d` / `]d` | Previous / next diagnostic |
| n | `<leader>rs` | Restart LSP |

### Completion (insert mode, nvim-cmp)

| Keys | Action |
|------|--------|
| `<C-Space>` | Trigger completion |
| `<C-j>` / `<C-k>` | Next / previous item |
| `<C-b>` / `<C-f>` | Scroll docs up / down |
| `<C-e>` | Close completion |
| `<CR>` | Confirm |

### Git

| Mode | Keys | Action |
|------|------|--------|
| n | `<leader>gb` | Git browse (open in remote) |
| n | `<leader>gl` | Git log |

Gitsigns runs with defaults — `]c` / `[c` for next/prev hunk, `<leader>h*` family for stage/unstage/preview.

### Folding

| Keys | Action |
|------|--------|
| `<leader>za` | Toggle fold under cursor |
| `<leader>zo` / `<leader>zc` | Open / close one level |
| `<leader>zO` / `<leader>zC` | Open / close all folds |

### Terminal / Claude Code

| Mode | Keys | Action |
|------|------|--------|
| n, t | `<leader>ai` | Toggle Claude Code terminal |
| n | `<leader>tt` / `<leader>th` / `<leader>tv` | Terminal / horizontal / vertical split |

### Format / lint

| Mode | Keys | Action |
|------|------|--------|
| n, v | `<leader>mp` | Format buffer or selection (conform) |
| n | `<leader>l` | Trigger linting (nvim-lint) |

### Treesitter text-objects

Selection (`a` = around / `i` = inside / `l` = left / `r` = right):

| Keys | Object |
|------|--------|
| `a=` `i=` `l=` `r=` | Assignment |
| `a:` `i:` `l:` `r:` | Object property |
| `aa` `ia` | Parameter |
| `ai` `ii` | Conditional |
| `al` `il` | Loop |
| `af` `if` | Function call |
| `am` `im` | Function/method definition |
| `ac` `ic` | Class |

Movement (with `;` / `,` to repeat):

| Keys | Target |
|------|--------|
| `]f` `[f` `]F` `[F` | Function call (start / end) |
| `]m` `[m` `]M` `[M` | Function/method def |
| `]c` `[c` `]C` `[C` | Class |
| `]i` `[i` `]I` `[I` | Conditional |
| `]l` `[l` `]L` `[L` | Loop |

Swap (with treesitter):

| Keys | Action |
|------|--------|
| `<leader>na` / `<leader>pa` | Swap parameter next / prev |
| `<leader>n:` / `<leader>p:` | Swap property next / prev |
| `<leader>nm` / `<leader>pm` | Swap function next / prev |

### Comment / surround / replace

These are plugin defaults — not customized:

| Keys | Plugin / action |
|------|-----------------|
| `gc{motion}` / `gcc` | Comment.nvim — toggle line/region comment |
| `gb{motion}` | Block comment |
| `ys{motion}{char}` | nvim-surround — add surround |
| `ds{char}` | Delete surround |
| `cs{old}{new}` | Change surround |
| `gr{motion}` | ReplaceWithRegister — replace target with register contents |

---

## Cross-tool notes

- **`Ctrl+Space`** appears in two places: tmux prefix (terminal context) and nvim-cmp completion trigger (insert mode). They don't collide because tmux is a terminal-level binding and nvim-cmp is editor-level — when you're typing in nvim inside tmux, `Ctrl+Space` reaches nvim first via tmux extended-keys passthrough.
- **`Alt + ;`** enters aerospace service mode at the OS level. Doesn't reach tmux or nvim.
- **`Hyper + letter`** is OS-level (aerospace) — never reaches the terminal.
- **vim-tmux-navigator** (`C-HJKL`) is bidirectional: walking past the edge of a vim split lands in the next tmux pane and vice versa.
