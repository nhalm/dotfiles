# herdr

[herdr](https://herdr.dev) is the multiplexer on both machines: an agent runtime
rather than a terminal multiplexer — persistent agent sessions, panes and tabs,
and git worktree management. It comes from mise, so it is pinned in
`shared/.config/mise/config.toml` and installed everywhere.

Config is `shared/.config/herdr/config.toml`, shared by both machines. herdr's
defaults already cover the bindings — `prefix+h/j/k/l` focuses panes,
`prefix+minus` splits, `prefix+z` zooms — so the file carries only the
deviations:

| Option | Value | Why |
|---|---|---|
| `keys.prefix` | `ctrl+space` | herdr's default is `ctrl+b` |
| `theme.name` | `tokyo-night` | matches ghostty, lualine and lazygit |
| `terminal.shell_mode` | `login` | login shells in every pane so `~/.zprofile` runs. The default `auto` only does this on macOS, which would leave Linux panes without `GOPATH`, `EDITOR` and the mise shims when the server outlives the session that started it |
| `terminal.new_cwd` | `follow` | new panes and tabs inherit the cwd they were opened from |
| `onboarding` | `false` | skip first-run onboarding |
| `keys.command` | `prefix+alt+g` → lazygit in a 90%×90% popup | |

`herdr --default-config` prints the full documented default;
`herdr config check` validates an edit.

## Neovim navigation

`ctrl+h/j/k/l` and `alt+h/j/k/l` are bound to `plugin_action` commands that
[herdr-splits.nvim](https://github.com/lmilojevicc/herdr-splits.nvim) answers.
herdr sees the key first, forwards it into Neovim when the focused pane is
running it, and moves or resizes the pane itself otherwise — so one key family
covers Neovim splits and herdr panes both.

The plugin detects herdr through `HERDR_ENV`, `HERDR_PANE_ID` and
`HERDR_BIN_PATH`, and needs herdr ≥ 0.7.0. `herdr server reload-config` applies
a config edit.

On macOS this is why AeroSpace focuses with `caps+hjkl` rather than `alt+hjkl`:
alt belongs to the resize half.

Session picking is herdr's own. `setup.sh` runs `check_herdr`, which only
reports the installed version — mise has already done the installing.

Because `ctrl+space` is the prefix, it does not reach the application. That
matters for nvim-cmp, whose completion trigger is `<C-Space>`: send a literal
one through herdr's send-prefix binding.
