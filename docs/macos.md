# macOS

fish as the login shell, AeroSpace tiling windows, sketchybar in place of the
system menu bar, and Karabiner turning caps lock into a modifier. Everything
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
| Q | Ghostty, Claude, ChatGPT |
| W | Vivaldi, Notion |
| E | Messages |
| R | 1Password, Zoom, Spotify, Screen Sharing — all floating — plus Wispr Flow, which tiles |
| T | Safari |

Finder floats without being assigned a workspace.

### Main mode

| Chord | Action |
|---|---|
| `caps+Q/W/E/R/T` | focus workspace |
| `caps+Shift+Q/W/E/R/T` | move window to workspace |
| `caps+Tab` | workspace back and forth |
| `caps+Shift+Tab` | move workspace to next monitor |
| `caps+M` | move workspace to next monitor |
| `Alt+h/j/k/l` | focus left/down/up/right |
| `caps+h/j/k/l` | move window |
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

Colours are hand-written TokyoNight Storm hex in `colors.lua` — not imported
from a theme file and not related to the Linux side's matugen palette.

This directory is a **GPLv3 fork of NoamFav/sketchybar**, kept under its own
licence. Its `README.md` and `install.sh` are upstream artifacts that no longer
describe this fork: `install.sh` has a `yourusername` placeholder repo URL and
would move the live config aside and then fail. Nothing in `platform/darwin/`
invokes it.

Dead code worth knowing about, since it is present but never loaded:
`items/apple.lua`, `front_app.lua`, `menus.lua`, `spaces.lua` (which drives
yabai, not AeroSpace), `media.lua`, `widgets/music.lua`, `widgets/git_toolkit.lua`.
`items/init.lua` also references a commented-out `items.spotify` that does not
exist. The `menus` C helper is still compiled on every start and needs
Accessibility permission plus private SkyLight symbols, though only the dead
`menus.lua` would use it.

`darwin/.config/sketchybar/.aerospace.toml` is a vendored upstream sample that
lands where AeroSpace never reads it. It contradicts the real config on almost
every setting — different modifiers, gaps, 31 workspaces, `start-at-login = false`.
Ignore it.

## fish

| Scope | Contents |
|---|---|
| Always | `brew shellenv`, `~/.local/bin` on PATH, `SSH_AUTH_SOCK` for the 1Password agent under `~/Library/Group Containers/`, `PROJECTS_DIR` |
| Non-interactive only | mise shims on PATH — for sketchybar and anything else that never sources a shell rc |
| Interactive | `mise activate`, `zoxide init --cmd cd` (zoxide replaces `cd`), aliases `tmf`, `tmc`, `vim` |

Plugins are installed by `post-link.sh`, not declared in `config.fish`: fisher,
`PatrickF1/fzf.fish`, `jorgebucaran/autopair.fish`, `jorgebucaran/nvm.fish`,
`ilancosman/tide@v6`, `vitallium/tokyonight-fish`.

Tide's own settings live in fish universal variables, which are not tracked —
`.gitignore` keeps `config.fish` and ignores the rest of the fish directory. The
prompt's exact appearance is therefore not reproducible from this repo, and
`nvm.fish` sits alongside mise, which already manages node.

`darwin/.zshrc` and `.zprofile` are vestigial from before the fish switch. They
are still stowed but nothing makes zsh the login shell here; `.zshrc` sources an
oh-my-zsh that the repo never installs, and the zsh plugins `setup.sh` clones
are for the Linux side and are never sourced by it.

## Terminals

Both Ghostty and Kitty are installed as casks. Ghostty's config is shared (see
the README); Kitty is macOS-only:

| Setting | Value |
|---|---|
| Theme | `tokyonight_storm.conf`, curled from folke/tokyonight.nvim by `post-link.sh` |
| Font | Monaspace Neon Var, 12pt, inside a generated `BEGIN_KITTY_FONTS` block |
| Scrollback | 10000 |
| macOS | no menubar icon, window title in window |

`darwin/.config/kitty/` holds only `kitty.conf`, so stow folds the directory and
`~/.config/kitty` becomes a symlink into the repo — which means that curled
theme file lands in the working tree as an untracked file.

Only AeroSpace rule for a terminal is Ghostty → workspace Q.

## Packages

`platform/darwin/packages.txt` — formulae, installed by `setup.sh`:

| Group | Contents |
|---|---|
| Core | bash, git, git-lfs, openssh, openssl, gnupg, moreutils, gnu-sed, coreutils, grep, wget, stow, p7zip, dos2unix, autoconf |
| Shell | fish, mise |
| Editor | neovim, tree-sitter-cli |
| Search | ack, ripgrep, fd, fzf, tree, bat, glow |
| Data | jq, yq |
| System | htop |
| Git | gh |
| Languages | yarn, openjdk, uv, php, composer, libyaml, readline (go comes from mise) |
| Cloud | awscli, aws-vault, helm, kubernetes-cli, terraform |
| Containers | colima, docker-compose — Colima runs the daemon, so only the docker CLI is installed, as a formula |
| Databases | postgresql@17 |
| Documents | imagemagick, ghostscript, tectonic |
| macOS | 1password-cli, karabiner-elements |

`casks.txt`, installed only by `gui.sh`: kitty, ghostty, cursor, brave-browser,
raycast, cleanshot, spotify, claude, chatgpt, 1password, aerospace.

`fonts.txt`, installed by `setup.sh`: font-monaspace, font-hack-nerd-font, and
for sketchybar sf-symbols, font-sf-mono, font-sf-pro, font-victor-mono-nerd-font,
font-sketchybar-app-font.

Installed outside those lists:

| Where | What |
|---|---|
| `setup.sh` | nix (used by nothing else in the repo), Homebrew, `brew trust --tap` for felixkratz/nikitabobko/hashicorp, the docker CLI formula, corelocationcli cask |
| `post-link.sh` | TPM, the docker compose CLI plugin symlink, the kitty theme, fisher and its plugins, npm globals carbonyl / mermaid-cli / ccusage |
| `gui.sh` | casks, sketchybar, borders, SbarLua from source |

AeroSpace window rules name Vivaldi, Notion, Zoom and Wispr Flow, none of which
`casks.txt` installs — the rules are inert until those are installed by hand.
