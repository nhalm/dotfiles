# macOS

zsh login shell, herdr multiplexer, AeroSpace tiling, sketchybar in place of the
system menu bar, Karabiner turning caps lock into a modifier. All of it is the
`darwin` stow package.

GUI applications install as part of `./setup.sh` (skip with `--no-gui`), or
standalone via `./platform/darwin/gui.sh`. That step installs the casks,
sketchybar and borders, builds SbarLua from source the first time, hides the
menu bar (`defaults write NSGlobalDomain _HIHideMenuBar`) and starts both brew
services. It is the only place in the repo that writes a macOS default.

## Modifiers

Karabiner has one rule: **caps lock emits `Cmd+Ctrl+Opt`** (⌘⌃⌥), with
`optional: ["any"]` so Shift rides along. AeroSpace binds it as
`ctrl-alt-cmd-*`.

macOS has no Super key — that is the X11/Wayland name for ⌘ — and ⌘ alone is
unusable as a window-manager modifier because apps own nearly every ⌘+letter.
The usual answer is a synthesized chord:

| | Modifiers |
|---|---|
| Hyper, the common caps lock convention | ⌘⌃⌥⇧ |
| Meh | ⌃⌥⇧ |
| Here | ⌘⌃⌥ |

Three rather than four so Shift stays free: caps+Shift yields ⌘⌃⌥⇧, keeping
the focus-vs-move split. Full Hyper would consume Shift and collapse
`caps+Shift+h` into `caps+h`.

The profile also opts a Logitech combo device (vendor 1133) into processing,
which Karabiner skips by default.

## AeroSpace

| Setting | Value |
|---|---|
| `config-version` | 2 |
| `persistent-workspaces` | `1`–`5`, explicit — v2 stops inferring them from keybindings, and without them a workspace vanishes with its last window, taking its sketchybar chip |
| Layout | tiles, orientation auto, accordion padding 30 |
| Gaps | 20 all round; top 15 on the built-in display, 42 elsewhere (sketchybar is 40 tall) |
| Normalization | flatten containers, opposite orientation for nested |
| On startup | `sketchybar`, then `borders active_color=0xffbb9af7 inactive_color=0xff494d64 width=5.0` |
| On workspace change | `sketchybar --trigger aerospace_workspace_change` |
| On monitor focus change | `move-mouse monitor-lazy-center` |
| Start at login | yes |

| Workspace | Apps |
|---|---|
| 1 | Ghostty, Claude, ChatGPT |
| 2 | Vivaldi, Notion |
| 3 | Messages |
| 4 | 1Password, Zoom, Spotify, Screen Sharing (floating), Wispr Flow (tiles) |
| 5 | Safari |

Finder floats with no workspace. The rules name Vivaldi, Notion, Zoom and Wispr
Flow, none of which `casks.txt` installs — those are inert until installed by
hand.

### Main mode

Chords mirror Hyprland's: caps stands in for `SUPER`, caps+Shift acts on the
window rather than the focus.

| Chord | Action |
|---|---|
| `caps+1..5` | focus workspace |
| `caps+Shift+1..5` | move window to workspace |
| `caps+h/j/k/l` | focus window |
| `caps+Shift+h/j/k/l` | move window |
| `caps+Tab` | workspace back and forth |
| `caps+Shift+Tab`, `caps+M` | move workspace to next monitor |
| `caps+w` | wallpaper picker |
| `Alt+h/j/k/l` | resize nvim splits / herdr panes — herdr-splits.nvim, not AeroSpace |
| `Alt+minus` / `Alt+equal` | resize smart ∓50 |
| `Alt+comma` / `Alt+slash` | accordion / tiles layout |
| `Alt+semicolon` | service mode |

`Alt+h/j/k/l` is deliberately left free of AeroSpace bindings so herdr-splits
can claim it.

### Service mode

| Key | Action |
|---|---|
| `h/j/k/l` | join with that neighbour, back to main |
| `r` | flatten the workspace tree |
| `f` | toggle floating / tiling |
| `backspace` | close all windows but the current one |
| `up` / `down` | volume |
| `Shift+down` | mute, back to main |
| `esc` | reload config, back to main |

## sketchybar

`sketchybarrc` runs under mise's Lua 5.5
(`#!/usr/bin/env -S mise x lua@5.5 -- lua`); SbarLua builds against it.
`helpers/` recompiles its C providers on every start, so sketchybar must launch
with the config directory as cwd.

Bar is 40px: AeroSpace workspace chips on the left; calendar, battery, volume,
wifi, cpu and weather on the right, each in its own bracket.

| Item | Detail |
|---|---|
| `aerospace_workspaces` | one chip per workspace, created once at load; refresh is two bulk `aerospace list-*` calls on the `aerospace_workspace_change`, `front_app_switched`, `display_change` and `system_woke` events. Click focuses, right-click moves the window |
| `calendar` | `%a. %d %b.` + `%H:%M`, 30s; click opens Calendar |
| `battery` | `pmset -g batt` every 180s, colour by level, popup shows time remaining |
| `volume` | percent + icon; popup has a slider and one row per output device via `SwitchAudioSource`; scroll adjusts, right-click opens Sound preferences |
| `wifi` | throughput from the compiled `network_load` provider on `en0`; popup shows SSID, hostname, IP, subnet, router, each row copying itself on click |
| `cpu` | 42px graph from the compiled `cpu_load` provider; click opens Activity Monitor |
| `weather` | wttr.in, location from `CoreLocationCLI` cached 30 min, exponential backoff to 6h on failure; right-click opens Weather |

`colors.lua` `pcall`-requires the matugen-generated `matugen-colors.lua` beside
it, falling back to a static TokyoNight Storm table when no palette exists.

Only `cpu_load` and `network_load` are compiled on each start; both are live.

This directory is a **GPLv3 fork of NoamFav/sketchybar** under its own licence.
Upstream's README, `install.sh` and unused items have been pruned.

## zsh

Both machines run the same `shared/.zshrc` and `shared/.zprofile`; only
`~/.config/zsh/os.zsh` differs.

| Where | Carries |
|---|---|
| `os.zsh` | Homebrew `site-functions` on `fpath`; `ls -G` / `ls -lahG` (BSD ls rejects `--color=auto`); `STARSHIP_CONFIG` when matugen has rendered one |
| `.zprofile` | `EDITOR`, `PROJECTS_DIR`, `GOPATH`, `~/.local/bin` and `$GOPATH/bin` on PATH, mise shims, `brew shellenv`, keg-only openjdk, `SSH_AUTH_SOCK` |

The fragment is sourced *before* `compinit`, which is what lets it extend
`fpath` in time.

`SSH_AUTH_SOCK` belongs in `.zprofile`, not the fragment — in `os.zsh` only
interactive shells would reach the 1Password agent.

Interactive extras come from the shared `.zshrc`, each guarded on the command
existing: `mise activate`, `zoxide init --cmd cd`, `starship init`, `fzf --zsh`.

Plugins are cloned by `install_zsh_plugins` into `~/.local/share/zsh/plugins`
rather than installed from brew, so the set is identical on both machines:
`zsh-autosuggestions`, `zsh-completions`, `fast-syntax-highlighting` — in that
order, highlighting last.

## Theming

matugen derives a Material palette from an image. Three templates render here;
the other eight are Wayland-only.

```bash
wallpaper.sh <image>     # set and re-render
wallpaper.sh --restore   # re-apply the remembered one
```

`caps+w` opens `wallpaper-picker.sh` in a Ghostty window AeroSpace floats:
`fzf`, thumbnails via `chafa` over the kitty graphics protocol, and the palette
each image would produce shown as swatches from `matugen --dry-run`. The float
rule matches on window title and must sit **above** the general Ghostty rule,
which would otherwise pull it to workspace 1.

Wallpapers come from `nhalm/wallpapers`, cloned to `~/Pictures/Wallpapers` by
`install_wallpapers`. `WALLPAPER_DIR` overrides.

| Template | Package | Output | Consumer | Reload |
|---|---|---|---|---|
| `ghostty-colors` | `shared` | `~/.config/ghostty/colors` | `?colors` include | `Cmd+Shift+,` or a new window |
| `starship.toml` | `shared` | `~/.local/state/matugen/starship.toml` | `STARSHIP_CONFIG` | next prompt |
| `sketchybar-colors.lua` | `darwin` | `~/.config/sketchybar/matugen-colors.lua` | `colors.lua` | `sketchybar --reload` |

The generated file is a flat dump of every Material role as `0xAARRGGBB`;
`colors.lua` maps those onto the names the bar's items use.

Borders are retinted by re-running `borders` with the generated `primary` and
`outline_variant`, which avoids restarting it. The static values in
`aerospace.toml` are what run at login.

Light/dark follows `defaults read -g AppleInterfaceStyle`; `MATUGEN_MODE`
overrides.

The desktop picture is set with `osascript`, which reaches every display but
only the current Space. Reaching the others means writing Dock's sqlite store,
whose shape changes between releases.

## Packages

`platform/darwin/packages.txt`, installed by `setup.sh`:

| Group | Contents |
|---|---|
| Core | bash, git, git-lfs, openssh, openssl, gnupg, moreutils, gnu-sed, coreutils, grep, wget, stow, p7zip, dos2unix, autoconf |
| Shell | mise, starship |
| Editor | neovim, tree-sitter-cli |
| Search | ack, ripgrep, fd, fzf, tree, bat, glow, chafa |
| Data | jq, yq |
| System | htop |
| Git | gh |
| Languages | yarn, openjdk, uv, php, composer, libyaml, readline (go comes from mise) |
| Cloud | awscli, aws-vault, helm, kubernetes-cli, `hashicorp/tap/terraform` |
| Containers | colima, docker-compose — Colima runs the daemon, so docker is the CLI only |
| Databases | postgresql@17 |
| Documents | imagemagick, ghostscript, tectonic |
| macOS | 1password-cli, karabiner-elements |

`terraform` is tap-qualified because it left homebrew-core with the BUSL
relicence. `1password-cli` and `karabiner-elements` resolve to casks despite
sitting here, so they prompt for a password.

`casks.txt`: ghostty, brave-browser, raycast, cleanshot, spotify, claude,
chatgpt, 1password, aerospace.

`fonts.txt`: font-monaspace, font-hack-nerd-font, and for sketchybar
sf-symbols, font-sf-mono, font-sf-pro, font-victor-mono-nerd-font,
font-sketchybar-app-font.

Installed outside those lists:

| Where | What |
|---|---|
| `setup.sh` | Homebrew, taps (felixkratz, nikitabobko, hashicorp — trusted *and* tapped, since trusting alone does not make a tap-qualified name resolve), the docker CLI formula, corelocationcli |
| `post-link.sh` | wallpapers, the docker compose plugin symlink, config checks for the stowed sketchybar Lua and aerospace |
| `gui.sh` | casks, sketchybar, borders, SbarLua from source |

## Terminal

Ghostty only; its config is shared with the Linux side. The one AeroSpace rule
is Ghostty → workspace 1.
