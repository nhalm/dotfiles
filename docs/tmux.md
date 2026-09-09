# Multiplexers

Two different tools, one muscle memory. macOS runs tmux; Linux runs
[herdr](https://herdr.dev). Both use `Ctrl+Space` as the prefix and both route
`Ctrl+h/j/k/l` between panes.

| | macOS | Arch |
|---|---|---|
| Tool | tmux + TPM | herdr |
| Config | `darwin/.tmux.conf` | `shared/.config/herdr/config.toml` |
| Prefix | `Ctrl+Space` | `Ctrl+Space` |
| Session picker | `tmux-sessionizer.sh` | herdr's own |

herdr is installed by mise on both machines, so it is available on macOS too;
only Linux uses it as the primary multiplexer.

## herdr (Arch)

An agent runtime rather than a terminal multiplexer: persistent agent sessions,
panes and tabs, and git worktree management. Its defaults already match the tmux
bindings closely — `prefix+h/j/k/l` focuses panes, `prefix+minus` splits,
`prefix+z` zooms — so the config carries only the deviations:

| Option | Value | Why |
|---|---|---|
| `keys.prefix` | `ctrl+space` | matches tmux instead of herdr's `ctrl+b` |
| `theme.name` | `tokyo-night` | matches ghostty, lualine and lazygit |
| `terminal.shell_mode` | `login` | login shells in every pane so `~/.zprofile` runs. The default `auto` only does this on macOS, which would leave Linux panes without `GOPATH`, `EDITOR` and the mise shims when the server outlives the session that started it |
| `terminal.new_cwd` | `follow` | new panes and tabs inherit the cwd they were opened from |
| `onboarding` | `false` | skip first-run onboarding |
| `keys.command` | `prefix+alt+g` → lazygit in a 90%×90% popup | |

`herdr --default-config` prints the full documented default; `herdr config check`
validates an edit.

## tmux (macOS)

Prefix is `Ctrl+Space`. `C-b` is unbound.

### Panes

| Chord | Action |
|---|---|
| `Ctrl+h/j/k/l` | focus pane left/down/up/right — no prefix |
| `prefix h/j/k/l` | same, with the prefix |
| `prefix H/J/K/L` | resize by 5, repeatable |
| `prefix \` | split left/right (`split-window -h`) |
| `prefix -` | split top/bottom (`split-window -v`) |

Bare `Ctrl+hjkl` is routed by a hand-written `if-shell` predicate, not the
vim-tmux-navigator plugin: if the pane's foreground process looks like vim,
nvim, view or **fzf**, the key is sent through instead of switching panes. That
`fzf` match means the keys reach an fzf popup rather than moving between panes.

### Sessions and windows

| Chord | Action |
|---|---|
| `prefix f` | sessionizer, **with** window setup (`--windows`) |
| `prefix F` | sessionizer, bare |
| `prefix b` | last session |
| `prefix X` | kill session, with confirmation |
| `prefix r` | reload `~/.tmux.conf` |
| `prefix C-Space` | send a literal `Ctrl+Space` to the pane |

`Ctrl+Space` is consumed by tmux as the prefix — it does not reach the
application. `send-prefix` exists for the cases where you need to deliver one,
which is also why nvim-cmp's `<C-Space>` completion trigger needs
`prefix C-Space` inside tmux.

### Options

| Option | Value |
|---|---|
| `default-terminal` | `tmux-256color`, with `xterm-256color:Tc` appended to overrides |
| `extended-keys` | on, `csi-u` format, `xterm*:extkeys` feature |
| `allow-passthrough` | on — kitty graphics, for Snacks image rendering in Neovim |
| `focus-events` | on |
| `escape-time` | 10 |
| `base-index` | 1 |
| `status-position` | top |
| `history-limit` | 10000 (tmux-sensible would otherwise set 50000) |
| `automatic-rename`, `set-titles` | on |

Mouse mode is off, and `mode-keys` is never set.

Plugins through TPM: `tmux-sensible` and `nhalm/tmux-tokyo-night` (storm
variant, powerline separators, datetime/weather/battery modules).

`post-link.sh` clones TPM into `~/.tmux/plugins/tpm`, which is what
`.tmux.conf` runs. The copy vendored at `darwin/tmux/plugins/tpm` stows to
`~/tmux/plugins/tpm` — no leading dot — so it is never the one that executes.

## tmux-sessionizer

`darwin/.local/scripts/tmux-sessionizer.sh`, run inside a `display-popup -E`.
Takes an optional directory argument to skip the picker, and `--windows` as the
first argument to lay out windows.

Candidates, in this order:

1. `Create new session...`
2. other existing tmux sessions
3. the current session
4. directories — every git repo up to two levels under `~/dev`, `~/Downloads`,
   `~/Documents`, `~/personal`, `~/work`, plus every top-level directory in
   those and in `~` itself

fzf previews a directory with `ls -la` and an existing session with
`capture-pane`, so you see what you are switching to.

Session names are the directory basename with `.` replaced by `_`. Picking an
existing session just switches to it — window setup is forced off in that case,
since the windows already exist.

With `--windows`, a newly created session gets three windows: `Agent` (window 1,
renamed), `terminal`, and `editor`, all rooted at the selected directory, with
`Agent` focused.

The shell alias `tmf` maps to the `--windows` form in fish and to the bare form
in the vestigial zsh config; `tmc` is the bare form.

## Known gap

`tmux` itself is not in `platform/darwin/packages.txt`. `post-link.sh` clones TPM
and stow links `.tmux.conf`, but nothing installs the binary — `brew install tmux`
is still a manual step, or add it to the package list.
