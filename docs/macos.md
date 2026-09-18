# macOS

zsh as the login shell, herdr as the multiplexer, AeroSpace tiling windows,
sketchybar in place of the system menu bar, and Karabiner turning caps lock
into a modifier. Everything
here is the `darwin` stow package.

GUI applications are not part of `./setup.sh` — several casks prompt for a
password:

```bash
./platform/darwin/gui.sh
```

That installs the casks, sketchybar and borders, builds SbarLua from source,
hides the system menu bar (`defaults write NSGlobalDomain _HIHideMenuBar`), and
starts both brew services. It is the only place in the repo that writes a macOS
default.

## Modifiers

Karabiner has exactly one rule: **caps lock emits `Cmd+Ctrl+Opt`**, with
`optional: ["any"]` so Shift rides along and caps+Shift gives
`Cmd+Ctrl+Opt+Shift`.

That three-modifier chord is what AeroSpace binds as `ctrl-alt-cmd-*`. Note it
is *not* the conventional four-modifier Hyper.

The profile also opts a Logitech combo keyboard/pointer device (vendor 1133)
into processing, which Karabiner skips by default.

## AeroSpace

| Setting | Value |
|---|---|
| Layout | tiles, orientation auto, accordion padding 30 |
| Gaps | 20 inner and outer; top 15 on the built-in display, 42 elsewhere (sketchybar is 40 tall) |
| Normalization | flatten containers, opposite orientation for nested containers |
| On startup | `sketchybar`, then `borders active_color=0xffbb9af7 inactive_color=0xff494d64 width=5.0` |
| On workspace change | `sketchybar --trigger aerospace_workspace_change` |
| On monitor focus change | `move-mouse monitor-lazy-center` |
| Start at login | yes |

Five workspaces, assigned by app:

| Workspace | Apps |
|---|---|
| 1 | Ghostty, Claude, ChatGPT |
| 2 | Vivaldi, Notion |
| 3 | Messages |
| 4 | 1Password, Zoom, Spotify, Screen Sharing — all floating — plus Wispr Flow, which tiles |
| 5 | Safari |

Finder floats without being assigned a workspace.

### Main mode

Chords mirror Hyprland's, with caps (`Cmd+Ctrl+Opt`) standing in for `SUPER`
and caps+Shift acting on the window rather than the focus.

| Chord | Action |
|---|---|
| `caps+1..5` | focus workspace |
| `caps+Shift+1..5` | move window to workspace |
| `caps+h/j/k/l` | focus window |
| `caps+Shift+h/j/k/l` | move window |
| `caps+Tab` | workspace back and forth |
| `caps+Shift+Tab` | move workspace to next monitor |
| `caps+M` | move workspace to next monitor |
| `caps+w` | wallpaper picker |
| `Alt+h/j/k/l` | resize nvim splits / herdr panes — herdr-splits.nvim, not AeroSpace |
| `Alt+minus` / `Alt+equal` | resize smart ∓50 |
| `Alt+comma` / `Alt+slash` | accordion / tiles layout |
| `Alt+semicolon` | enter service mode |

### Service mode

| Key | Action |
|---|---|
| `h/j/k/l` | join with that neighbour, then back to main |
| `r` | flatten the workspace tree |
| `f` | toggle floating / tiling |
| `backspace` | close all windows but the current one |
| `up` / `down` | volume up / down |
| `Shift+down` | mute, then back to main |
| `esc` | reload config and return to main |

## sketchybar

`sketchybarrc` runs under the mise-managed Lua 5.5
(`#!/usr/bin/env -S mise x lua@5.5 -- lua`), which is why
`conf.d/darwin.toml` pins `lua = "5.5"` — SbarLua builds against it. `helpers/`
recompiles its C event providers on every start, so sketchybar must be launched
with the config directory as its working directory.

Bar is 40px. Left side is AeroSpace workspace chips; right side is calendar,
battery, volume, wifi, cpu and weather, each in its own bracket.

| Item | Detail |
|---|---|
| `aerospace_workspaces` | one chip per workspace, created once at load; refresh is two bulk `aerospace list-*` calls, driven by the `aerospace_workspace_change`, `front_app_switched`, `display_change` and `system_woke` events. Click focuses, right-click moves the window there |
| `calendar` | `%a. %d %b.` + `%H:%M`, 30s; click opens Calendar |
| `battery` | `pmset -g batt` every 180s, colour by level, popup shows time remaining |
| `volume` | percent + icon, popup with a slider and one row per output device via `SwitchAudioSource`; scroll adjusts, right-click opens Sound preferences |
| `wifi` | up/down throughput from the compiled `network_load` provider on `en0`; popup shows SSID, hostname, IP, subnet and router, each row copying itself to the clipboard on click |
| `cpu` | 42px graph from the compiled `cpu_load` provider; click opens Activity Monitor |
| `weather` | wttr.in, location from `CoreLocationCLI` cached 30 min, exponential backoff up to 6h on failure; right-click opens Weather |

Colours come from `colors.lua`, which `pcall`-requires the matugen-generated
`matugen-colors.lua` beside it and falls back to a static TokyoNight Storm table
when no palette has been rendered — the same shape as the Hyprland side's
`looks.lua`. See Theming below.

This directory is a **GPLv3 fork of NoamFav/sketchybar**, kept under its own
licence. Upstream's `README.md`, `install.sh` and unused items have been pruned;
`LICENCE` stays.

Only two C helpers are compiled on each start, both live: `cpu_load` feeds the
cpu graph and `network_load` feeds the wifi throughput readout.

## zsh

Both machines run the same `shared/.zshrc` and `shared/.zprofile`. History,
completion styles, keybindings and the plugin loading order are identical; only
`~/.config/zsh/os.zsh` differs, and on macOS that comes from the `darwin`
package:

| What | Value |
|---|---|
| `SSH_AUTH_SOCK` | `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` — Linux uses `~/.1password/agent.sock` |
| `fpath` | Homebrew's `share/zsh/site-functions` prepended, so brew completions work |
| Colour flags | `ls -G` / `ls -lahG`; BSD ls rejects GNU's `--color=auto` |
| Aliases | `tmf` (sessionizer `--windows`), `tmc` (bare) |

The fragment is sourced *before* `compinit`, which is what lets it extend
`fpath` in time.

`.zprofile` carries the environment: `EDITOR`, `PROJECTS_DIR`, `GOPATH`,
`~/.local/bin` and `$GOPATH/bin` on PATH, plus mise shims for processes that
never source a shell rc — sketchybar being the one that matters here.
Homebrew's `shellenv` runs from there too, guarded on `/opt/homebrew/bin/brew`
existing.

Interactive extras come from the shared file, each guarded on the command being
present: `mise activate`, `zoxide init --cmd cd` (zoxide takes over `cd`),
`starship init`, and `fzf --zsh`.

Plugins are cloned by `install_zsh_plugins` (`lib/common.sh:114`) into
`~/.local/share/zsh/plugins`, not installed from brew, so the set is byte-identical
on both machines: `zsh-autosuggestions`, `zsh-completions`,
`fast-syntax-highlighting` — loaded in that order, highlighting last.

## Terminals

Ghostty is the only terminal, and its config is shared with the Linux side (see
the README). The only AeroSpace rule for a terminal is Ghostty → workspace 1.

## Theming

matugen derives a Material palette from an image, the same way the Arch machine
does. Three templates render here; the other eight are Wayland-only.

```bash
wallpaper.sh <image>     # a specific image
wallpaper.sh --restore
```

Choosing one interactively is `wallpaper-picker.sh`'s job — `caps+w`, which
AeroSpace launches into a Ghostty window it floats. The picker draws thumbnails with `chafa` over the kitty graphics protocol, and
shows the palette each image would produce as truecolor swatches beside it,
from `matugen --dry-run`. Applying calls `wallpaper.sh`.

The float rule matches on window title and must sit above the general Ghostty
rule, which would otherwise pull the picker to workspace 1.

Wallpapers come from `nhalm/wallpapers`, cloned to `~/Pictures/Wallpapers` by
`install_wallpapers` in `post-link.sh`. `WALLPAPER_DIR` overrides.

| Template | Package | Output | Consumer | Reload |
|---|---|---|---|---|
| `ghostty-colors` | `shared` | `~/.config/ghostty/colors` | `?colors` include | `Cmd+Shift+,` or a new window |
| `starship.toml` | `shared` | `~/.local/state/matugen/starship.toml` | `STARSHIP_CONFIG`, set by `os.zsh` | next prompt |
| `sketchybar-colors.lua` | `darwin` | `~/.config/sketchybar/matugen-colors.lua` | `colors.lua` | `sketchybar --reload` |

The generated file is a flat dump of every Material role as `0xAARRGGBB`;
`colors.lua` maps those onto the names the bar's items use.

`wallpaper.sh` retints borders by re-running `borders` with the generated
`primary` and `outline_variant`, which avoids restarting it. The static values
in `aerospace.toml` are what run at login.

Light/dark follows the system appearance
(`defaults read -g AppleInterfaceStyle`). `MATUGEN_MODE` overrides it.

matugen has no Homebrew formula, so it comes from crates.io through mise's
cargo backend (`conf.d/darwin.toml`).

The desktop picture is set with `osascript`, which reaches every display but
only the current Space — the other Spaces keep theirs. Reaching them means
writing Dock's sqlite store, whose shape changes between releases.

## Packages

`platform/darwin/packages.txt` — formulae, installed by `setup.sh`:

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
| Cloud | awscli, aws-vault, helm, kubernetes-cli, terraform |
| Containers | colima, docker-compose — Colima runs the daemon, so only the docker CLI is installed, as a formula |
| Databases | postgresql@17 |
| Documents | imagemagick, ghostscript, tectonic |
| macOS | 1password-cli, karabiner-elements |

`casks.txt`, installed only by `gui.sh`: ghostty, brave-browser, raycast,
cleanshot, spotify, claude, chatgpt, 1password, aerospace.

`fonts.txt`, installed by `setup.sh`: font-monaspace, font-hack-nerd-font, and
for sketchybar sf-symbols, font-sf-mono, font-sf-pro, font-victor-mono-nerd-font,
font-sketchybar-app-font.

Installed outside those lists:

| Where | What |
|---|---|
| `setup.sh` | Homebrew, `brew trust --tap` for felixkratz/nikitabobko/hashicorp, the docker CLI formula, corelocationcli cask |
| `post-link.sh` | wallpapers, the docker compose CLI plugin symlink, then config checks for the stowed sketchybar Lua and aerospace |
| `gui.sh` | casks, sketchybar, borders, SbarLua from source |

AeroSpace window rules name Vivaldi, Notion, Zoom and Wispr Flow, none of which
`casks.txt` installs — the rules are inert until those are installed by hand.
