# Neovim

Shared between both machines, in `shared/.config/nvim/`. lazy.nvim manages
plugins, Mason manages LSP servers and tools, snacks provides pickers and the
explorer, conform formats and nvim-lint lints.

Leader is `Space`. Colourscheme is `tokyonight-storm`.

## Layout

```
init.lua                    two lines: require nhalm.core, then nhalm.lazy
lua/nhalm/core/init.lua     keymaps then options, in that order
lua/nhalm/core/keymaps.lua  leader, and every keymap not owned by a plugin
lua/nhalm/core/options.lua  vim.opt, providers, vim.filetype.add
lua/nhalm/lazy.lua          lazy.nvim bootstrap and setup options
lua/nhalm/plugins/*.lua     one file per plugin, each returning a lazy spec
lua/nhalm/plugins/init.lua  specs that need no config of their own
lua/nhalm/plugins/lsp/*.lua lspconfig, mason — a second explicit import group
ftplugin/markdown.lua       buffer-local options per filetype
lazy-lock.json              committed lockfile, 40 plugins
.luacheckrc, stylua.toml    lint and format config for this config
```

Keymaps are required before options so `mapleader` is set before lazy loads.

Adding a plugin is adding a file under `lua/nhalm/plugins/` that returns a
table — the directory is imported wholesale, so nothing needs registering.
LSP-related plugins go in `plugins/lsp/`, which is imported separately because
the top-level import is not recursive. Global keymaps belong in
`core/keymaps.lua`; plugin-scoped ones belong in that plugin's spec, under
`keys =` when it should lazy-load.

## Keymaps

### Editing

| Mode | Keys | Action |
|---|---|---|
| i | `jk` | escape |
| n | `<leader>nh` | clear search highlight |
| n | `<leader>+` / `<leader>-` | increment / decrement number |
| n, v | `<leader>mp` | format buffer or selection (conform) |
| n | `<leader>l` | lint now |

### Windows and tabs

| Mode | Keys | Action |
|---|---|---|
| n | `<leader>sv` / `<leader>sh` | split vertical / horizontal |
| n | `<leader>se` / `<leader>sx` | equalize / close split |
| n | `<leader>s+` / `<leader>s-` | height ±2 |
| n | `<leader>s>` / `<leader>s<` | width ±2 |
| n | `<leader>sm` | maximize / restore |
| n | `<C-h/j/k/l>` | navigate splits (tmux-aware on macOS) |
| n | `<C-\>` | previous split |
| n | `<leader>to` / `<leader>tx` | open / close tab |
| n | `<leader>tn` / `<leader>tp` | next / previous tab |
| n | `<leader>tf` | current buffer in a new tab |
| t | `<C-w>` | leave terminal mode, then window command |

`<C-h/j/k/l>` go through vim-tmux-navigator, which only has a counterpart on
macOS; on Linux they are plain window moves.

### Finding (snacks)

| Keys | Action |
|---|---|
| `<leader>e` | explorer |
| `<leader>ff` / `<leader>fg` | files / live grep |
| `<leader>fb` / `<leader>fr` | buffers / recent |
| `<leader>fh` / `<leader>fk` | help / keymaps |
| `<leader>fc` | colourschemes |
| `<leader>bd` | dashboard |

### Sessions

| Keys | Action |
|---|---|
| `<leader>wr` / `<leader>ws` | restore / save session for the cwd |

auto-session does not auto-restore, and skips `~`, `~/Dev`, `~/Downloads`,
`~/Documents` and `~/Desktop`.

### LSP

Buffer-local, attached per server.

| Mode | Keys | Action |
|---|---|---|
| n | `gd` / `gD` | definitions / declaration |
| n | `gR` / `gi` / `gt` | references / implementations / type definitions |
| n | `K` | hover |
| n, v | `<leader>ca` | code action |
| n | `<leader>rn` | rename |
| n | `<leader>D` / `<leader>d` | diagnostics picker / line diagnostics |
| n | `[d` / `]d` | previous / next diagnostic |
| n | `<leader>rs` | restart LSP |

### Completion (nvim-cmp, insert mode)

| Keys | Action |
|---|---|
| `<C-Space>` | trigger |
| `<C-j>` / `<C-k>` | next / previous |
| `<C-b>` / `<C-f>` | scroll docs |
| `<C-e>` | abort |
| `<CR>` | confirm, without preselect |

Inside tmux on macOS, `Ctrl+Space` is the tmux prefix — use `prefix C-Space` to
deliver one here.

### Git

| Keys | Action |
|---|---|
| `<leader>gg` | lazygit |
| `<leader>gb` | open in remote |
| `<leader>gl` | git log |

Gitsigns runs on defaults, so its hunk mappings are the stock buffer-local ones.
Note `]c` / `[c` are **also** bound globally by treesitter to class movement;
gitsigns' buffer-local maps win inside a tracked file, and outside one these
navigate classes.

### Terminal and Claude Code

| Mode | Keys | Action |
|---|---|---|
| n, t | `<leader>ai` | toggle Claude Code |
| n, t | `<leader>tt` | terminal |
| n | `<leader>th` / `<leader>tv` | terminal bottom / right |

`claudecode.nvim` runs `claude` in a snacks terminal at the bottom, 80%×40%, and
its diff view is disabled.

### Folds

| Keys | Action |
|---|---|
| `<leader>za` | toggle fold |
| `<leader>zo` / `<leader>zc` | open / close one level |
| `<leader>zO` / `<leader>zC` | open / close all |

nvim-origami sets `foldlevel` and `foldlevelstart` to 99, so files open unfolded.

### Treesitter text objects

Select, in visual and operator-pending. `a` around, `i` inside, `l` left-hand
side, `r` right-hand side:

| Keys | Object |
|---|---|
| `a=` `i=` `l=` `r=` | assignment |
| `a:` `i:` `l:` `r:` | object property |
| `aa` `ia` | parameter |
| `ai` `ii` | conditional |
| `al` `il` | loop |
| `af` `if` | function call |
| `am` `im` | function or method definition |
| `ac` `ic` | class |

Movement — lowercase to a start, uppercase to an end, `]` forward, `[` back:

| Keys | Target |
|---|---|
| `]f` `[f` `]F` `[F` | function call |
| `]m` `[m` `]M` `[M` | function or method |
| `]c` `[c` `]C` `[C` | class |
| `]i` `[i` `]I` `[I` | conditional |
| `]l` `[l` `]L` `[L` | loop |

Swap:

| Keys | Action |
|---|---|
| `<leader>na` / `<leader>pa` | parameter next / previous |
| `<leader>n:` / `<leader>p:` | property next / previous |
| `<leader>nm` / `<leader>pm` | function next / previous |

`;` and `,` repeat the last move forward and backward — and `f`, `F`, `t`, `T`
are replaced by treesitter's repeatable versions, so `;` repeats those too
instead of `;`/`,` behaving as vim's stock repeat.

### Plugin defaults, not configured here

| Keys | Plugin |
|---|---|
| `gc{motion}`, `gcc`, `gb{motion}` | Comment.nvim |
| `ys{motion}{char}`, `ds{char}`, `cs{old}{new}` | nvim-surround |
| `gr{motion}` | ReplaceWithRegister — shares the `gr` prefix with Neovim 0.11's built-in `grn`/`gra`/`grr`/`gri` LSP maps |

## LSP, formatting, linting

Mason installs 13 servers: ts_ls, html, cssls, tailwindcss, svelte, lua_ls,
graphql, emmet_ls, prismals, pyright, marksman, gopls, elixirls. All are enabled
through the `vim.lsp.config` / `vim.lsp.enable` API with a shared `on_attach` and
cmp capabilities.

Server specifics worth knowing:

| Server | Configuration |
|---|---|
| ts_ls | formatting providers disabled — prettier owns JS/TS formatting |
| gopls | `-tags=integration unit`, completeUnimported, placeholders, unusedparams, staticcheck, gofumpt |
| pyright | workspace diagnostics, `venvPath = "."`, `venv = ".venv"` |
| elixirls | dialyzer off, fetchDeps off |
| svelte | extra autocmd notifying the server when a `.js`/`.ts` file is written |
| graphql, emmet_ls | restricted to their relevant filetypes |
| lua_ls | `vim` global, runtime files as workspace library |

mason-tool-installer adds stylua, ruff, eslint_d, gofumpt, golines, goimports,
gotests and golangci-lint.

conform, with format-on-save and LSP fallback:

| Filetypes | Formatter |
|---|---|
| svelte, css, html, json, yaml, markdown, graphql, liquid | prettier |
| lua | stylua |
| python | ruff_fix, ruff_format, ruff_organize_imports |
| go | gofumpt, goimports |
| elixir, heex, eelixir | mix |

nvim-lint, on BufEnter, BufWritePost and InsertLeave:

| Filetypes | Linter |
|---|---|
| javascript, typescript, react variants, svelte | eslint_d |
| python | ruff (prefers `$cwd/.venv/bin/ruff`) |
| go | golangcilint |
| lua | luacheck |

26 treesitter parsers are installed, on the `main` branch (the rewrite).

## Options

Relative + absolute line numbers, 2-space expanded tabs, no wrap, smartcase
search, cursorline, termguicolors, `signcolumn=yes`, splits right and below, no
swapfile, system clipboard, and **mouse disabled entirely**.

`.mdx` files are treated as markdown, and `.luacheckrc` as conf. Markdown
buffers turn wrap and linebreak on.

Perl and Ruby providers are off. `python3_host_prog` is set only if
`~/.pyenv/versions/neovim/bin/python` exists.

## Rough edges

None of these break anything day to day, but they will confuse anyone reading
the config:

- JS and TS have **no formatter**: conform's `javascript`/`typescript`/`*react`
  entries are commented out *and* ts_ls's formatting capabilities are disabled.
- No `go` or `python` treesitter parser, despite full LSP, formatting and
  linting for both.
- `lazy.setup`'s `install.colorscheme` names `nightfly`, which no installed
  plugin provides.
- lazydev's `luvit-meta/library` and the pyenv `python3_host_prog` both point at
  things nothing installs — the repo manages python through mise.
- `mason.nvim` is declared twice under different owners — `williamboman/mason.nvim`
  in `plugins/lsp/mason.lua`, and `mason-org/mason.nvim` pinned to `^1.0.0` in
  `plugins/mason-workaround.lua`. Nothing records which spec wins or why the pin
  is there.
- prettier formats eight filetypes but is not in the mason tool list; golines
  and gotests are installed and unused; luacheck is used and not installed.
- `lazyvim.json` and `plugins/lsp/none-ls.lua` are dead — LazyVim is not used and
  none-ls returns an empty spec.

Run `:checkhealth` after a fresh install.
