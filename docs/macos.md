# macOS

zsh login shell, herdr multiplexer, AeroSpace tiling, sketchybar in place of the
system menu bar, Karabiner turning caps lock into a modifier. All of it is the
`darwin` stow package.

GUI applications install as part of `./setup.sh` (skip with `--no-gui`), or
standalone via `./platform/darwin/gui.sh`. That step also hides the menu bar
(`defaults write NSGlobalDomain _HIHideMenuBar`), the only macOS default the
repo writes.

## Modifiers

Karabiner has one rule: **caps lock emits `Cmd+Ctrl+Opt`** (⌘⌃⌥), with
`optional: ["any"]` so Shift rides along. AeroSpace binds it as
`ctrl-alt-cmd-*`.

| | Modifiers |
|---|---|
| Hyper, the common caps lock convention | ⌘⌃⌥⇧ |
| Meh | ⌃⌥⇧ |
| Here | ⌘⌃⌥ |

Three rather than four leaves Shift free, so caps+Shift yields ⌘⌃⌥⇧ and the
focus-vs-move split holds.

The profile also opts a Logitech combo device (vendor 1133) into processing,
which Karabiner skips by default.

## AeroSpace

| Setting | Value |
|---|---|
| `config-version` | 2 |
| `persistent-workspaces` | `1`–`6`, explicit — without them a workspace vanishes with its last window, taking its sketchybar chip |
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
| 6 | unassigned |

Finder floats with no workspace.

### Main mode

caps+Shift acts on the window rather than the focus.

| Chord | Action |
|---|---|
| `caps+1..6` | focus workspace |
| `caps+Shift+1..6` | move window to workspace |
| `caps+h/j/k/l` | focus window |
| `caps+Shift+h/j/k/l` | move window |
| `caps+Tab` | workspace back and forth |
| `caps+Shift+Tab`, `caps+M` | move workspace to next monitor |
| `caps+w` | wallpaper picker |
| `Alt+h/j/k/l` | resize nvim splits / herdr panes — herdr-splits.nvim, not AeroSpace |
| `Alt+minus` / `Alt+equal` | resize smart ∓50 |
| `Alt+comma` / `Alt+slash` | accordion / tiles layout |
| `Alt+semicolon` | service mode |

`Alt+h/j/k/l` is left free of AeroSpace bindings for herdr-splits.

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
(`#!/usr/bin/env -S mise x lua@5.5 -- lua`); SbarLua builds against that version,
which is why `conf.d/darwin.toml` pins it. `helpers/` recompiles its C
providers on every start, so sketchybar must launch with the config directory
as cwd.

Bar is 40px: workspace chips on the left, everything else on the right.

| Item | Detail |
|---|---|
| `aerospace_workspaces` | one chip per workspace, refreshed on the `aerospace_workspace_change`, `front_app_switched`, `display_change` and `system_woke` events. Click focuses, right-click moves the window |
| `calendar` | `%a. %d %b.` + `%H:%M`, 30s; click opens Calendar |
| `battery` | `pmset -g batt` every 180s, colour by level, popup shows time remaining |
| `volume` | percent + icon; popup has a slider and one row per output device via `SwitchAudioSource`; scroll adjusts, right-click opens Sound preferences |
| `wifi` | throughput from the compiled `network_load` provider on `en0`; popup shows SSID, hostname, IP, subnet, router, each row copying itself on click |
| `cpu` | 42px graph from the compiled `cpu_load` provider; click opens Activity Monitor |
| `weather` | wttr.in, location from `CoreLocationCLI` cached 30 min, exponential backoff to 6h on failure; right-click opens Weather |

`colors.lua` falls back to a static TokyoNight Storm table when the
matugen-generated `matugen-colors.lua` beside it does not exist.

This directory is a **GPLv3 fork of NoamFav/sketchybar** under its own licence.

## zsh

`shared/.zshrc` and `shared/.zprofile` are shared; `~/.config/zsh/os.zsh` is
the macOS fragment.

| Where | Carries |
|---|---|
| `os.zsh` | Homebrew `site-functions` on `fpath`; `ls -G` / `ls -lahG` (BSD ls rejects `--color=auto`); `STARSHIP_CONFIG` when matugen has rendered one |
| `.zprofile` | `EDITOR`, `PROJECTS_DIR`, `GOPATH`, `~/.local/bin` and `$GOPATH/bin` on PATH, mise shims, `brew shellenv`, keg-only openjdk, `SSH_AUTH_SOCK` |

The fragment is sourced *before* `compinit`, so it can extend `fpath` in time.

`SSH_AUTH_SOCK` belongs in `.zprofile`, not the fragment — in `os.zsh` only
interactive shells would reach the 1Password agent.

Interactive extras come from the shared `.zshrc`, each guarded on the command
existing: `mise activate`, `zoxide init --cmd cd`, `starship init`, `fzf --zsh`.

Plugins are cloned by `install_zsh_plugins` into `~/.local/share/zsh/plugins`:
`zsh-autosuggestions`, `zsh-completions`, `fast-syntax-highlighting` — in that
order, highlighting last.

## Theming

matugen derives a Material palette from an image. Four templates render here.

```bash
wallpaper.sh <image>     # set and re-render
wallpaper.sh --restore   # re-apply the remembered one
```

`caps+w` opens `wallpaper-picker.sh` in a Ghostty window AeroSpace floats. The
float rule matches on window title and must sit **above** the general Ghostty
rule, which would otherwise pull it to workspace 1.

Wallpapers come from `nhalm/wallpapers`, cloned to `~/.local/share/wallpapers` by
`install_wallpapers`. `WALLPAPER_DIR` overrides.

| Template | Package | Output | Consumer | Reload |
|---|---|---|---|---|
| `ghostty-colors` | `shared` | `~/.config/ghostty/colors` | `?colors` include | SIGUSR2, sent by `wallpaper.sh` |
| `starship.toml` | `shared` | `~/.local/state/matugen/starship.toml` | `STARSHIP_CONFIG` | next prompt |
| `sketchybar-colors.lua` | `darwin` | `~/.config/sketchybar/matugen-colors.lua` | `colors.lua` | `sketchybar --reload` |
| `zen-colors.css` | `shared` | `~/.local/state/matugen/zen-colors.css` | `userChrome.css` `@import` | live, within 5s |

`link_zen_theme` runs in post-link: it resolves the profile from `profiles.ini` —
the `[Install*]` section, not the one marked `Default=1` — symlinks the render
into `chrome/zen-matugen.css`, prepends the `@import` to `userChrome.css`, and
sets `toolkit.legacyUserProfileCustomizations.stylesheets` in `user.js`.

`install_zen_autoconfig` puts `lib/zen/zen-matugen.cfg` and its prefs file into
`Zen.app/Contents/Resources`. Zen reads `userChrome.css` only at startup, so
that script polls the rendered palette every 5s and loads it into open windows
as a user-origin sheet.

It also installs `distribution/policies.json`, which disables Zen's updater:
an update replaces the bundle and takes the other two files with it, ending the
live reload silently. Updating Zen is therefore deliberate -- do it, then re-run
`./setup.sh`.

Writing into the bundle needs App Management for the terminal, in System
Settings > Privacy & Security. Without it the install step says so and skips.

Borders are retinted by re-running `borders` with the generated `primary` and
`outline_variant`. The static values in `aerospace.toml` are what run at login.

Light/dark follows `defaults read -g AppleInterfaceStyle`; `MATUGEN_MODE`
overrides.

The desktop picture is set with `osascript`, which reaches every display but
only the current Space.

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

`1password-cli` and `karabiner-elements` resolve to casks despite sitting here,
so they prompt for a password.

`casks.txt`: ghostty, brave-browser, zen, raycast, cleanshot, spotify, claude,
chatgpt, 1password, aerospace.

`fonts.txt`: font-monaspace, font-hack-nerd-font, and for sketchybar
sf-symbols, font-sf-mono, font-sf-pro, font-victor-mono-nerd-font,
font-sketchybar-app-font.

Installed outside those lists:

| Where | What |
|---|---|
| `setup.sh` | Homebrew, taps (felixkratz, nikitabobko, hashicorp — trusted *and* tapped), the docker CLI formula, corelocationcli |
| `post-link.sh` | wallpapers, the docker compose plugin symlink, the Zen theme link, config checks for the stowed sketchybar Lua and aerospace |
| `gui.sh` | casks, sketchybar, borders, SbarLua from source |

## Terminal

Ghostty only; its config is in the `shared` package. The one AeroSpace rule is
Ghostty → workspace 1.
