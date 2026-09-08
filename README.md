# dotfiles

Personal configuration for macOS and Arch Linux, linked with GNU stow.

## Install

On a new machine:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nhalm/dotfiles/main/bootstrap.sh)
```

`bootstrap.sh` installs just enough to proceed (git, stow, a compiler
toolchain), clones this repo to `~/dotfiles`, and hands off to `setup.sh`.

Process substitution rather than `curl … | bash` is deliberate: piping ties up
stdin, which breaks the `sudo` prompt the package installs need.

If the repo is already cloned:

```bash
./setup.sh              # packages, links, tools
./setup.sh --link-only  # re-link configs only (same as ./make_links.sh)
```

Everything is idempotent — re-run it whenever.

On macOS, GUI applications are a separate manual step, because several casks
prompt for a password:

```bash
./platform/darwin/gui.sh
```

## How the platform split works

Differences fall on two axes, and keeping them separate is what stops a third
distro from being a rewrite:

- **OS family** (`darwin` / `linux`) — launchd vs systemd, `/Applications` vs
  `/opt`, BSD vs GNU coreutils.
- **Distro** (`macos` / `arch` / …) — which package manager speaks, and what
  the packages are called.

`lib/detect.sh` resolves both from `uname` and `/etc/os-release`. A derivative
with no entry of its own falls back to what its `ID_LIKE` names, so EndeavourOS
or CachyOS reuse the Arch package list and stow package with no new files.

### Layout

```
bootstrap.sh          curl target for a fresh machine
setup.sh              entrypoint: detect → packages → link → tools
make_links.sh         re-link only

lib/
  detect.sh           OS_FAMILY / DISTRO / DISTRO_LIKE, and which dirs apply
  pkg.sh              pkg_install() → brew | pacman+yay | apt | dnf
  common.sh           stow, mise, zsh plugins, claude, github gpg

platform/
  darwin/             setup.sh, post-link.sh, gui.sh, packages.txt, casks.txt, fonts.txt
  linux/              setup.sh (any distro)
    arch/             setup.sh, post-link.sh, packages.txt, aur.txt

shared/               stow package: everything portable
darwin/               stow package: macOS only
linux/                stow package: any Linux
arch/                 stow package: Arch only (hypr, waybar, swaync)
```

Stow packages are linked nearest-last: `shared`, then the OS family, then the
distro. Only the ones that exist are used.

### Per-file differences

When a config is *mostly* shared but needs one OS-specific line, the shared file
includes a fragment that each OS package provides, rather than the whole file
being duplicated:

| Shared file | Includes | Provided by |
|---|---|---|
| `.gitconfig` | `~/.config/git/os.conf` | 1Password signing binary path |
| `.zshrc` | `~/.config/zsh/os.zsh` | SSH agent socket, GNU vs BSD `ls` |
| `mise/config.toml` | `mise/conf.d/*.toml` | per-OS runtimes (mise merges additively) |

`.zshrc` also sources `~/.config/zsh/local.zsh` if present — per-machine
overrides, gitignored.

### Adding a distro

1. Add a case to `_resolve_backend` in `lib/pkg.sh` if no existing backend fits.
2. Create `platform/linux/<distro>/packages.txt` and a `setup.sh`.
3. Create a `<distro>/` stow package only if a config genuinely differs.

### Linking safety

`stow_package` moves any *real* file already at a target path aside to
`<path>.dotfiles-backup` before linking. This replaces `stow --adopt`, which
resolves conflicts the wrong way round — it pulls the machine's version *into*
the repo, silently overwriting the config you were installing.

## What's on each machine

|  | macOS | Arch |
|---|---|---|
| Shell | fish + tide | zsh + starship |
| Multiplexer | tmux + TPM | [herdr](https://herdr.dev) |
| Window manager | AeroSpace | Hyprland |
| Status bar | sketchybar | waybar |
| Notifications | — | swaync *(under review)* |
| Network / Bluetooth | — | nm-applet + blueman (tray) |
| Display layout | — | nwg-displays |
| Key remapping | Karabiner | *(not set up)* |
| Containers | Colima + docker CLI | native docker |
| Terminal | Ghostty, Kitty | Ghostty |
| Editor | Neovim | Neovim |

The Arch package set is deliberately smaller than the Mac's — the cloud and
infra tooling (awscli, kubectl, helm, terraform), the JVM/PHP stack, and the
document toolchain are macOS-only. Add them to
`platform/linux/arch/packages.txt` if that changes.

## Hyprland (Arch)

Config is Lua, split into modules under `arch/.config/hypr/`, with
`hyprland.lua` as a table of contents:

| Module | Holds |
|---|---|
| `monitors.lua` | outputs and scaling |
| `programs.lua` | terminal/launcher/browser, referenced by keybinds and rules |
| `colors.lua` | TokyoNight Storm palette, shared with the waybar CSS |
| `looks.lua` | gaps, borders, decoration, animations |
| `input.lua` | keyboard, touchpad, gestures |
| `keybinds.lua` | all bindings |
| `rules.lua` | window rules |
| `autostart.lua` | waybar, swaync, polkit agent, nm-applet, 1Password |

Bindings follow the conventional Hyprland scheme — `SUPER` plus `h/j/k/l` to
focus, `SUPER+SHIFT` to move, `SUPER+1..0` for workspaces. Three fixes relative
to the stock generated config:

- `SUPER+P` was bound twice (file manager, then pseudo), so it never opened the
  file manager. That's on `SUPER+E` now.
- `SUPER+J` (togglesplit) collided with `SUPER+j` (focus down). Togglesplit
  moved to `SUPER+V`.
- Focus directions had `j`→right and `l`→down. Now `h/j/k/l` is
  left/down/up/right.

### Display layout

The layout is deliberately **not** in this repo -- it is machine-specific, and
identical monitors differ only by serial, so connector names like `DP-1`/`DP-2`
can swap between boots.

Arrange displays by dragging them in `nwg-displays`, which writes
`~/.config/hypr/monitors.lua`. That file is untracked and unstowed;
`hyprland.lua` loads `monitors_default.lua` first and then `pcall`s it, so it
overrides the defaults when present and is simply absent on a fresh machine.

Tick **"use monitor descriptions"** in nwg-displays so its rules match on
description/serial rather than connector name.

### Lid / clamshell

Closing the lid disables the internal panel and leaves the externals running.
The suspend half needs no configuration: `logind` selects
`HandleLidSwitchDocked` -- which defaults to `ignore` -- whenever more than one
display is connected, so the machine stays awake while docked and still
suspends when the lid is closed on its own.

`~/.local/scripts/hypr-lid.sh` reads the kernel lid state rather than trusting
which switch edge fired, since `switch:on`/`switch:off` has been unreliable for
lids in the Lua config. It uses `hyprctl eval`, not `hyprctl keyword` -- a
Lua-configured Hyprland rejects `keyword` outright while still exiting 0, which
is why most clamshell recipes found online silently do nothing here.

Nothing draws a wallpaper — `force_default_wallpaper = 0` disables the mascot
and no wallpaper daemon is installed. Add `hyprpaper` or `swaybg` if you want
one.

### Brightness keys

`XF86MonBrightness*` needs the `brightnessctl` package, which the stock Arch
install does not include -- that alone is why the keys do nothing on a fresh
system.

Setup also adds you to the `video` group, but that is only a fallback:
brightnessctl links `libsystemd` and goes through logind, which needs no
permissions on `/sys/class/backlight/*/brightness` for the active session. The
file stays `root:root 644` and the keys work anyway.

## Shells

### zsh (Arch)

`starship` prompt from a single `starship.toml`, plus three plugins cloned by
`lib/common.sh` rather than packaged, so the set is identical everywhere:
`zsh-autosuggestions`, `zsh-completions`, `fast-syntax-highlighting`. fzf's own
zsh integration provides `Ctrl+R` / `Ctrl+T`, so no plugin manager is involved.

### fish (macOS)

Tide prompt, with fisher plugins for fzf, autopair, and nvm.

## Runtimes

[mise](https://mise.jdx.dev/) manages language runtimes on both machines.
Shared: Node LTS, Python 3.13, Go, Rust, plus zoxide, lazygit, herdr, and
ccstatusline. macOS adds Lua 5.5 (SbarLua builds against it), Ruby, and Bun
through `conf.d`.

Configs are trusted during setup so shims resolve for processes that never
source a shell rc — systemd units, GUI launchers, sketchybar.

## Neovim

Lazy.nvim, LSP via Mason, Telescope/snacks for navigation, Treesitter,
Gitsigns, auto-session, which-key, conform + nvim-lint. Shared between both
machines. Run `:checkhealth` after setup.

## Git

SSH commit signing through 1Password, `https://github.com/` rewritten to SSH,
per-directory identity (`~/work` and `~/dev` are work, `~/personal` and
`~/dotfiles` are personal), and rebase-on-pull.

`bootstrap.sh` clones over https because no SSH key exists yet; `setup.sh`
switches the remote to SSH at the end, once the 1Password agent is available.

## Keybindings

See [CHEATSHEET.md](CHEATSHEET.md) — currently the macOS reference.

## Machine-specific / private setup

Host-specific and sensitive setup (backups, sync, vault) lives in the private
`host-setup` repo, not here.
