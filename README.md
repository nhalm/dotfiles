# dotfiles

Personal configuration for macOS and Arch Linux, linked with GNU stow.

| Doc | Covers |
|---|---|
| [docs/linux.md](docs/linux.md) | Arch: Hyprland, quickshell bar, notifications, theming, monitors, scripts |
| [docs/macos.md](docs/macos.md) | macOS: AeroSpace, sketchybar, Karabiner, theming, packages |
| [docs/neovim.md](docs/neovim.md) | Neovim: layout, plugins, keymaps |
| [docs/herdr.md](docs/herdr.md) | herdr: the multiplexer on both machines |

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nhalm/dotfiles/main/bootstrap.sh)
```

Installs git, stow and a compiler toolchain, clones to `~/dotfiles`, runs
`setup.sh`. Swap `main` for a SHA to pin what you execute. Use process
substitution, not `curl … | bash`, which breaks the sudo prompt.

```bash
./setup.sh                # everything: packages, GUI apps, links, tools
./setup.sh --no-gui       # skip the GUI applications
./setup.sh --link-only    # re-link stow packages only
./setup.sh --diff-system  # preview writes under /etc, change nothing
```

`./setup.sh` is also the update command. Every step is idempotent. Several
casks prompt for a password.

### Installing needs no key

| | Needs a key |
|---|---|
| Packages, links, runtimes, plugins, wallpapers | no |
| `git commit` | yes — `commit.gpgsign` with the signer from `os.conf` |
| `git pull` in `~/dotfiles` | yes — `use_ssh_remote` sets origin to ssh |
| `authorized_keys`, sshd drop-in | yes — written once the agent serves keys |

setup installs 1Password itself. Sign in, enable its SSH agent, re-run
`./setup.sh`.

The sshd drop-in is refused while `authorized_keys` is empty.

## Platform detection

| Axis | Values | Decides |
|---|---|---|
| `OS_FAMILY` | `darwin`, `linux` | launchd vs systemd, BSD vs GNU coreutils |
| `DISTRO` | `macos`, `arch`, … | which package manager speaks |

`lib/detect.sh` resolves both from `uname` and `/etc/os-release`; a derivative
with no entry falls back to its `ID_LIKE`.

### Layout

```
bootstrap.sh          curl target for a fresh machine
setup.sh              detect → packages → link → post-link → tools
make_links.sh         wrapper for ./setup.sh --link-only

lib/
  detect.sh           OS_FAMILY / DISTRO / DISTRO_LIKE / CPU_ARCH
  pkg.sh              pkg_install() → brew | pacman + yay | apt | dnf
  common.sh           stow, mise, zsh plugins, wallpapers, git signing, ssh keys
  system.sh           writes under /etc, and --diff-system

platform/
  darwin/             setup.sh, post-link.sh, gui.sh, packages.txt, casks.txt, fonts.txt
  linux/              setup.sh (any distro)
    arch/             setup.sh, post-link.sh, packages.txt, aur.txt

system/linux/etc/     root-owned drop-ins installed into /etc

shared/  darwin/  linux/  arch/     stow packages
```

`setup.sh` sources `platform/<family>/setup.sh` then `<distro>/setup.sh`, links,
then runs both `post-link.sh` scripts.

### Stow packages

| Package | Holds |
|---|---|
| `shared` | zsh, nvim, git, ssh, mise, ghostty, lazygit, herdr, psqlrc, gitleaks, ccstatusline, claude, portable matugen templates |
| `darwin` | aerospace, sketchybar, karabiner, matugen, `.local/scripts`, git/zsh/ssh OS fragments |
| `linux` | git, zsh and ssh OS fragments |
| `arch` | hypr, quickshell, swaync, matugen, fuzzel, gtk, qt, `.local/scripts` |

Linked nearest-last: `shared`, then the OS family, then the distro.

`stow_package` moves a real file at a target path to `<path>.dotfiles-backup`
before linking.

`--no-folding` keeps directories under `~` real, so generated files written
beside a linked one do not land in the working tree.

### Per-file differences

| Shared file | Fragment | Carries |
|---|---|---|
| `.gitconfig` | `~/.config/git/os.conf` | 1Password signer path |
| `mise/config.toml` | `mise/conf.d/*.toml` | every tool, per scope; merged additively |
| `ghostty/config` | `?colors` | matugen output; optional, absent until it runs |
| `.zshrc` | `~/.config/zsh/os.zsh` | ls flags, completions, aliases |
| `.ssh/config` | `~/.ssh/config.os` | `IdentityAgent` — the 1Password socket path |

`.zshrc` sources its fragment **before** `compinit`, so the fragment can extend
`fpath`. `~/.config/zsh/local.zsh` is sourced last, and is gitignored.

`.ssh/config` includes its fragment **above** `Host *`: ssh_config takes the
first value it sees for a keyword.

`SSH_AUTH_SOCK` lives in the shared `.zprofile`, not `os.zsh`, so
non-interactive shells reach the agent too.

### Adding a distro

1. Add a case to `_resolve_backend` in `lib/pkg.sh` if no backend fits.
2. Create `platform/linux/<distro>/packages.txt` and `setup.sh`.
3. Create a `<distro>/` stow package only if a config genuinely differs.

## What's on each machine

| | macOS | Arch |
|---|---|---|
| Shell | zsh + starship | zsh + starship |
| Multiplexer | [herdr](https://herdr.dev) | [herdr](https://herdr.dev) |
| Window manager | AeroSpace | Hyprland (Lua config) |
| Bar | sketchybar | quickshell |
| Notifications | — | swaync |
| Launcher | Raycast | hyprlauncher, fuzzel for dmenu pickers |
| Wallpaper picker | fzf + chafa in a floating Ghostty | quickshell carousel |
| Display layout | — | nwg-displays |
| Key remapping | Karabiner | — |
| Containers | Colima + docker CLI | native docker |
| Terminal | Ghostty | Ghostty |
| Editor | Neovim | Neovim |
| Theming | matugen | matugen |

51 formulae, 9 casks and 7 font casks on macOS; 106 repo packages and 3 AUR on
Arch. macOS-only: cloud/infra tooling, the JVM/PHP stack, ghostscript and tectonic.
Arch-only: the Hyprland session, kernel and hardware packages, `arch-audit`.

## Runtimes

[mise](https://mise.jdx.dev/) manages runtimes on both machines. Every tool
lives in `~/.config/mise/conf.d/`; `config.toml` holds only `[settings]`.

| File | Package | Tools |
|---|---|---|
| `conf.d/shared.toml` | `shared` | Node 24, Go 1, Rust 1, zoxide, lazygit, herdr, `npm:ccstatusline` |
| `conf.d/darwin.toml` | `darwin` | Lua 5.5, Ruby 3, Bun, `cargo:matugen`, `npm:carbonyl`, `npm:@mermaid-js/mermaid-cli`, `npm:ccusage` |

Tools name a major version, so `mise upgrade` never crosses a major. Two
exceptions: `lua` stays on 5.5 for SbarLua, and `carbonyl` names an exact build
because it publishes only prereleases, which mise filters out of a range.

`cargo:matugen` must stay out of `shared`: Arch installs matugen from pacman,
and a second copy would be resolved inconsistently.

No global python; pin it per project.

`auto_install` and `not_found_auto_install` are on, `idiomatic_version_file_enable_tools`
is node only. Configs are trusted during setup.

### Which installer owns a tool

**Never `npm install -g`, bare `cargo install`, or `pip install --user`.** Those
prefixes belong to the *active* runtime, so anything installed that way is
orphaned silently on the next major bump.

| Kind of thing | Goes to | Examples |
|---|---|---|
| Language runtime | mise | node, go, rust, ruby, lua, bun |
| Same version on both machines | `conf.d/shared.toml` | herdr, lazygit, zoxide, ccstatusline |
| Compiled tool the package manager carries | `packages.txt` | ripgrep, fzf, jq, neovim, starship, chafa |
| Tool it does *not* carry, but a registry does | `conf.d/<os>.toml` | `cargo:matugen`, `npm:ccusage` |
| GUI application | `casks.txt` | ghostty, raycast, 1password |

Prefer the package manager where it has the tool.

### Updating

`./setup.sh` upgrades everything: `brew upgrade`, `pacman -Syu`, and
`mise upgrade`.

| Command | Does |
|---|---|
| `mise outdated` | what is behind, within its range |
| `mise upgrade` | move those forward; add a tool name for one |
| `mise outdated --bump` | what is newer but outside the range |
| `mise upgrade --bump` | rewrite the config to the newer range, then upgrade |

`--bump` edits a file symlinked into this repo, so it belongs in a commit.

mise holds back releases younger than 24h (`minimum_release_age`), so a tool
published yesterday reports as up to date.

## Git

| Setting | Value |
|---|---|
| Signing | SSH format, `allowedSignersFile = ~/.config/git/allowed_signers`, signer from 1Password |
| Identity | `~/work` and `~/dev` → work; `~/personal` and `~/dotfiles` → personal |
| Pull | rebase |
| Default branch | `main` |
| Hooks | `core.hooksPath = ~/.config/git/hooks` |
| Integrity | `fsckObjects` on transfer, fetch and receive |
| LFS | filter tracked in `.gitconfig`, not appended by `git lfs install` |

No top-level `user.email`: a repo outside the `includeIf` directories has no
identity and git refuses to commit.

`core.hooksPath` is global and holds only `pre-commit`, so repo-local
`commit-msg`, `pre-push` and similar (husky, lefthook) are disabled
machine-wide. `pre-commit` chains back to a repo-local hook if one exists.

## Security

| Where | What |
|---|---|
| `system/linux/etc/` | Root-owned drop-ins: sshd, sysctl, faillock, docker daemon |
| `platform/linux/arch/post-link.sh` | ufw default-deny, ssh rate-limited, `system/` tree, `paccache.timer` |
| `lib/system.sh` | Installs root-owned `0644`, validates with `sshd -t` before reload |
| `shared/.config/git/hooks/pre-commit` | gitleaks on staged content, global via `core.hooksPath` |
| `shared/.gitignore_global` | Credential paths |
| `shared/.ssh/config` | No agent forwarding, hashed known_hosts, keys from 1Password |
| `shared/.claude/settings.json` | Deny rules for credential paths and unrecoverable commands |
| `lib/pkg.sh` | AUR PKGBUILDs logged before building; everything `--noconfirm` |

### Inbound SSH

`system/linux/etc/ssh/sshd_config.d/99-hardening.conf`: `PasswordAuthentication no`,
`AuthenticationMethods publickey`, `PermitRootLogin no`, `AllowUsers nick`,
post-quantum and modern KEX, AEAD ciphers, ETM MACs, ed25519 host keys only, no
forwarding, `MaxAuthTries 3`, `LoginGraceTime 20`.

`authorize_ssh_keys` writes the agent's public keys to `~/.ssh/authorized_keys`.

Restrict ssh to the LAN:

```bash
sudo ufw delete limit 22/tcp
sudo ufw allow from 192.168.0.0/16 to any port 22 proto tcp
```

## Rebuilding

1. Install Arch with [nhalm/arch-install](https://github.com/nhalm/arch-install),
   which lays down what this repo assumes: LUKS, btrfs + snapper, pipewire,
   NetworkManager, bluetooth, printing.
2. Run the one-liner above.
3. Sign in to 1Password, enable its SSH agent, re-run `./setup.sh` for the ssh
   hardening.

Install a package by hand, then add it to the relevant `packages.txt`.

## Credits

Hyprland configs written against [ML4W](https://github.com/mylinuxforwork/dotfiles)
by Stephan Raabe. [nhalm/wallpapers](https://github.com/nhalm/wallpapers) is a
subset of [their collection](https://github.com/mylinuxforwork/wallpaper).

## Licence

MIT. Vendored `darwin/.config/sketchybar/` (GPL-3.0) keeps its own.

Host-specific and sensitive setup (backups, sync, vault) lives in the private
`host-setup` repo.
