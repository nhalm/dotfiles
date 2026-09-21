# herdr

Installed by mise (`conf.d/shared.toml`); config is
`shared/.config/herdr/config.toml`, which carries only deviations from the
defaults:

| Option | Value | Why |
|---|---|---|
| `keys.prefix` | `ctrl+space` | default is `ctrl+b` |
| `theme.name` | `tokyo-night` | matches ghostty, lualine, lazygit |
| `terminal.shell_mode` | `login` | so `~/.zprofile` runs in every pane; `auto` only does this on macOS |
| `terminal.new_cwd` | `follow` | panes inherit the cwd they opened from |
| `onboarding` | `false` | |
| `keys.command` | `prefix+alt+g` → lazygit in a 90%×90% popup | |

`herdr --default-config` prints the documented default; `herdr config check`
validates an edit.

`ctrl+space` never reaches the application — send a literal one through
send-prefix for nvim-cmp's `<C-Space>`.

## Neovim navigation

`ctrl+h/j/k/l` moves between Neovim splits and herdr panes; `alt+h/j/k/l`
resizes. Provided by
[herdr-splits.nvim](https://github.com/lmilojevicc/herdr-splits.nvim), which
needs herdr ≥ 0.7.0.

**Two installs are required.** `setup.sh` handles both; by hand:

```bash
herdr plugin install lmilojevicc/herdr-splits.nvim --yes   # herdr side
herdr server reload-config
```

Without the herdr side the keys dead-end, and `herdr config check` still
reports `config: ok`. Verify with `herdr plugin action list`, which should show
eight actions under `herdr-splits`.

The Neovim plugin is guarded on `HERDR_ENV`, so it is not downloaded until nvim
first runs inside a herdr pane. `core/keymaps.lua` keeps `<C-w>` fallbacks on
the same keys.
