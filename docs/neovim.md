# Neovim

Shared by both machines, in `shared/.config/nvim/`. lazy.nvim loads one file
per plugin from `lua/nhalm/plugins/` (LSP plugins in `plugins/lsp/`); global
keymaps are in `core/keymaps.lua`, plugin ones in each spec's `keys`. Leader is
`Space`. `<leader>fk` searches every keymap.

Choices that aren't defaults:

- The mouse is off.
- The colourscheme is tokyonight, recoloured from the wallpaper by matugen
  (`:MatugenReload`, which `wallpaper.sh` sends to every running instance).
- Clipboard is the system clipboard; no swapfile.
- In a terminal buffer, `<M-a>` toggles Claude Code and `<M-t>` a terminal;
  `<leader>` maps are normal mode only, so typing Space in a terminal isn't
  delayed.
- auto-session saves and restores only on `<leader>ws` / `<leader>wr`.

## LSP, formatting, linting

Mason installs the servers and tools; `lspconfig.lua` enables them with one
`on_attach`. conform formats on save (prettier, stylua, ruff, gofumpt +
goimports, mix) and nvim-lint lints on write (eslint_d, ruff, golangci-lint,
luacheck). Mason needs `npm` and `go` on `PATH`, both from mise.

## herdr

`<C-h/j/k/l>` moves between splits and, at the edge, into the next herdr pane;
`<M-h/j/k/l>` resizes. This is
[herdr-splits.nvim](https://github.com/lmilojevicc/herdr-splits.nvim), and it
needs a plugin on each side: the Neovim one loads only inside herdr
(`HERDR_ENV=1`), and setup installs the herdr one. `herdr config check` passes
even without the herdr side, so check with `herdr plugin action list`. Outside
herdr the same keys are plain `<C-w>` moves.

herdr's prefix is `Ctrl+Space`, so nvim-cmp's `<C-Space>` needs herdr's
send-prefix.

## Known gaps

- No `go` or `python` treesitter parser, despite LSP, formatting and linting
  for both.
- luacheck is used but not installed.

Run `:checkhealth` after a fresh install.
