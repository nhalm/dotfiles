# herdr

[herdr](https://herdr.dev) is the multiplexer on both machines — an agent
runtime rather than a terminal multiplexer: persistent agent sessions, panes and
tabs, git worktree management. It comes from mise (`conf.d/shared.toml`), so it
is installed everywhere.

Config is `shared/.config/herdr/config.toml`, shared by both machines. The
defaults already cover the bindings — `prefix+h/j/k/l` focuses panes,
`prefix+minus` splits, `prefix+z` zooms — so the file carries only deviations:

| Option | Value | Why |
|---|---|---|
| `keys.prefix` | `ctrl+space` | default is `ctrl+b` |
| `theme.name` | `tokyo-night` | matches ghostty, lualine, lazygit |
| `terminal.shell_mode` | `login` | so `~/.zprofile` runs in every pane; the default `auto` only does this on macOS, leaving Linux panes without `GOPATH`, `EDITOR` and the mise shims |
| `terminal.new_cwd` | `follow` | panes and tabs inherit the cwd they opened from |
| `onboarding` | `false` | skip first-run onboarding |
| `keys.command` | `prefix+alt+g` → lazygit in a 90%×90% popup | |

`herdr --default-config` prints the documented default; `herdr config check`
validates an edit. Session picking is herdr's own.

`ctrl+space` never reaches the application, which matters for nvim-cmp's
`<C-Space>` completion trigger — send a literal one through send-prefix.

## Neovim navigation

`ctrl+h/j/k/l` and `alt+h/j/k/l` are bound to `plugin_action` commands that
[herdr-splits.nvim](https://github.com/lmilojevicc/herdr-splits.nvim) answers,
so one key family covers Neovim splits and herdr panes both. herdr sees the key
first, forwards it into Neovim when that pane is running it, and moves or
resizes the pane itself otherwise.

**It takes two installs.** The Neovim plugin only covers nvim → herdr; it shells
out to `herdr pane edges` and `herdr pane focus`. Crossing the other way needs
the herdr-side plugin, which registers the `nav-*` and `resize-*` actions the
bindings name. `install_herdr_plugins` in `setup.sh` handles it; by hand:

```bash
herdr plugin install lmilojevicc/herdr-splits.nvim --yes
herdr server reload-config
```

**Nothing warns you if it is missing.** `herdr config check` reports
`config: ok` for a binding naming a plugin that was never installed, and the
keys then dead-end — herdr consumes them and nothing moves. The real check is
`herdr plugin action list`, which should show eight actions under
`herdr-splits`.

Needs herdr ≥ 0.7.0. The lazy spec is guarded on `HERDR_ENV`, so the Neovim
plugin is not downloaded until nvim first runs inside a herdr pane;
`core/keymaps.lua` keeps `<C-w>` fallbacks on the same keys for everywhere else.

On macOS this is why AeroSpace focuses with `caps+hjkl` rather than `alt+hjkl`
— alt belongs to the resize half.
