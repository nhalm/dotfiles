# dotfiles

My configuration for macOS and CachyOS (Arch), linked with GNU stow.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nhalm/dotfiles/main/setup.sh)
```

Installs git, clones to `~/dotfiles` and runs the rest from there. Use process
substitution, not `curl … | bash`, which takes the stdin sudo needs. Swap
`main` for a commit SHA to pin what you run.

```bash
~/dotfiles/setup.sh              # packages, links, tools; also the update command
~/dotfiles/setup.sh --link-only  # re-link only
```

It prints everything it will do and asks first; Ctrl-C stops it. Every step is
safe to re-run. Setup creates a passphrase-protected
`~/.ssh/id_ed25519` and prints the `gh ssh-key add` commands; add it to GitHub
for authentication and signing, then re-run.

On CachyOS, install with Limine, encrypted btrfs, No Desktop, and the default
package selection minus "CachyOS shell configuration".

## Layout

```
setup.sh            packages → links → OS setup → runtimes, plugins, tools → ssh key
install/            common.sh, macos.sh, linux.sh, Brewfile, pacman.txt, aur.txt, karabiner.json
shared/             stow package for both OSes: zsh, nvim, git, ssh, mise, ghostty, herdr, lazygit, psql
macos/              AeroSpace, sketchybar, matugen, scripts
linux/              Hyprland, hypridle/hyprlock, swaync, fuzzel, gtk, matugen, scripts
docs/               linux.md, macos.md, neovim.md
```

`shared` is linked, then the OS package. A real file in the way is moved to
`<path>.dotfiles-backup`. Files are linked one by one (`--no-folding`), so
anything an app writes next to its config stays out of the repo.

| On | macOS | Linux |
|---|---|---|
| Window manager | AeroSpace | Hyprland (Lua config) |
| Bar | sketchybar + [barpop](https://github.com/nhalm/barpop) | [hyprland-quickshell](https://github.com/nhalm/hyprland-quickshell) |
| Launcher | Raycast | hyprlauncher, fuzzel |
| Containers | Colima + docker CLI | docker |
| Both | zsh + starship, [herdr](https://herdr.dev), Ghostty, Neovim, colours from the wallpaper via matugen | |

## Local overrides

| File | Read by | For |
|---|---|---|
| `~/.config/zsh/local.zsh` | `.zshrc` | per-machine shell setup |
| `~/.ssh/config.local` | `.ssh/config` | host aliases |
| `~/.config/git/identity.conf` | `.gitconfig` | name and email, optionally per directory; without it git refuses to commit |
| `~/.config/hypr/monitors.lua` | Hyprland | monitor layout, written by nwg-displays |

## Adding a tool

| Kind | Goes in |
|---|---|
| Language runtime, or a tool wanted at the same version everywhere | `shared/.config/mise/conf.d/shared.toml` |
| Packaged by Homebrew or pacman | `install/Brewfile` or `install/pacman.txt` |
| Only on a registry (npm, crates) | mise, as `npm:<name>` or `cargo:<name>` |
| GUI app on macOS | `install/Brewfile` cask |

Never `npm install -g`, `cargo install` or `pip install --user`: they install
into the active runtime and are orphaned at its next major version.

## Git

Commits are signed with `~/.ssh/id_ed25519`. The global hooks directory runs
each repo's own `pre-commit` and `pre-push`, then gitleaks on staged changes
and `git lfs pre-push`. Other repo-local hooks (`commit-msg`, husky, lefthook)
don't run, because `core.hooksPath` is global.

## SSH agent

The key's passphrase is entered once:

- **Linux:** gcr's agent stores it in the login keyring, which ly unlocks at login.
- **macOS:** setup stores it in Keychain, and a login item (`install/ssh-add.plist`)
  loads the key into the agent at every login, before any app needs it.

## Credits

Hyprland configs written against [ML4W](https://github.com/mylinuxforwork/dotfiles)
by Stephan Raabe; [nhalm/wallpapers](https://github.com/nhalm/wallpapers) is a
subset of [their collection](https://github.com/mylinuxforwork/wallpaper).

## Licence

MIT. The vendored `macos/.config/sketchybar/` keeps its GPL-3.0 licence.
