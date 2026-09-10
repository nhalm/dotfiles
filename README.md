# dotfiles

Personal configuration for macOS and Arch Linux, linked with GNU stow.

| Doc | Covers |
|---|---|
| [docs/linux.md](docs/linux.md) | Arch: Hyprland, the quickshell bar, notifications, theming, monitors, scripts, zsh |
| [docs/macos.md](docs/macos.md) | macOS: AeroSpace, sketchybar, Karabiner, fish, GUI applications |
| [docs/neovim.md](docs/neovim.md) | Neovim: layout, plugins, keymaps — shared by both machines |
| [docs/tmux.md](docs/tmux.md) | Multiplexers: tmux + sessionizer on macOS, herdr on Linux |

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nhalm/dotfiles/main/bootstrap.sh)
```

`bootstrap.sh` installs git, stow and a compiler toolchain, clones this repo to
`~/dotfiles`, and executes `setup.sh`.

Process substitution rather than `curl … | bash`: piping occupies stdin, which
breaks the `sudo` prompt the package installs need.

The URL tracks `main`. To pin what you execute to a reviewed commit, swap `main`
for a full SHA.

Once cloned:

```bash
./setup.sh                # packages, links, post-link, tools
./setup.sh --link-only    # re-link stow packages only (same as ./make_links.sh)
./setup.sh --diff-system  # preview writes under /etc, change nothing
```

Every step is idempotent.

macOS GUI applications are a separate command, because several casks prompt for
a password:

```bash
./platform/darwin/gui.sh
```

### Installing needs no key

`.gitconfig` requires signed commits and rewrites every GitHub https url to ssh.
Both are deliberate. The rewrite is unconditional, though, and that includes the
four anonymous clones of public repos setup performs on itself — the zsh
plugins, wallpapers, TPM and SbarLua. GitHub authenticates every ssh connection
whether the repo is public or not, so on a machine with no key those four would
fail. They go through `git_public`, which drops the global config for that one
command and re-passes the integrity checks it carries.

So a fresh machine installs in one command. What it cannot do until 1Password is
signed in is commit, or update this repo:

| | Needs a key | Why |
|---|---|---|
| Packages, links, runtimes, plugins, wallpapers | no | `git_public` keeps them on https |
| `git commit` | yes | `commit.gpgsign = true` with the signer from `os.conf` |
| `git pull` in `~/dotfiles` | yes | the https → ssh rewrite, and `use_ssh_remote` sets origin to ssh |
| `~/.ssh/authorized_keys`, sshd hardening drop-in | yes | written once the agent serves keys; skipped with a notice otherwise |

setup installs 1Password itself (`platform/linux/arch/aur.txt` on Arch,
`platform/darwin/casks.txt` on macOS). Sign in, enable the SSH agent, then
re-run `./setup.sh`.

The sshd drop-in is refused while `~/.ssh/authorized_keys` is empty: disabling
password authentication with no authorised key locks the account out of ssh.

## Platform detection

Differences fall on two axes, kept separate so a third distro is not a rewrite:

| Axis | Values | Decides |
|---|---|---|
| `OS_FAMILY` | `darwin`, `linux` | launchd vs systemd, `/Applications` vs `/opt`, BSD vs GNU coreutils |
| `DISTRO` | `macos`, `arch`, … | which package manager speaks, and what packages are called |

`lib/detect.sh` resolves both from `uname` and `/etc/os-release`. A derivative
with no entry of its own falls back to its `ID_LIKE`, so EndeavourOS and CachyOS
reuse the Arch package lists and stow package with no new files.

### Layout

```
bootstrap.sh          curl target for a fresh machine
setup.sh              detect → packages → link → post-link → tools
make_links.sh         wrapper for ./setup.sh --link-only

lib/
  detect.sh           OS_FAMILY / DISTRO / DISTRO_LIKE / CPU_ARCH, and which dirs apply
  pkg.sh              pkg_install() → brew | pacman + yay | apt | dnf
  common.sh           stow, mise, zsh plugins, wallpapers, git signing, ssh keys
  system.sh           writes under /etc, and --diff-system

platform/
  darwin/             setup.sh, post-link.sh, gui.sh, packages.txt, casks.txt, fonts.txt
  linux/              setup.sh (any distro)
    arch/             setup.sh, post-link.sh, packages.txt, aur.txt

system/linux/etc/     root-owned drop-ins installed into /etc

shared/               stow: portable config
darwin/               stow: macOS only
linux/                stow: any Linux
arch/                 stow: Arch only
```

`setup.sh` sources `platform/<family>/setup.sh` then
`platform/<family>/<distro>/setup.sh`, links, then runs the same two
`post-link.sh` scripts. Family first, so a distro script builds on it.

### Stow packages

| Package | Holds |
|---|---|
| `shared` | nvim, git, ssh, mise, ghostty, lazygit, herdr, psqlrc, gitleaks, ccstatusline, claude |
| `darwin` | fish, tmux, aerospace, sketchybar, karabiner, kitty |
| `linux` | zsh, starship, git and zsh OS fragments |
| `arch` | hypr, quickshell, swaync, matugen, fuzzel, gtk, qt, `.local/scripts` |

Linked nearest-last: `shared`, then the OS family, then the distro. Only
packages that exist are used.

`stow_package` moves any *real* file at a target path aside to
`<path>.dotfiles-backup` before linking, rather than using `stow --adopt`, which
resolves conflicts the other way round — pulling the machine's version into the
repo and overwriting the config being installed.

Linking uses `--no-folding`, so every file is linked individually and the
directories under `~` stay real. A folded directory is a symlink *into* the
repo, which means anything written next to a linked file — a matugen palette, a
theme downloaded at setup, a machine-local override — lands in the working tree.
This is what lets matugen write `colors.css` beside the `gtk.css` that imports
it.

### Per-file differences

A config that is mostly shared but needs OS-specific values includes a fragment
that each package provides, instead of the whole file being duplicated:

| Shared file | Includes | Provided by |
|---|---|---|
| `.gitconfig` | `~/.config/git/os.conf` | 1Password signer path, per OS package |
| `mise/config.toml` | `mise/conf.d/*.toml` | per-OS runtimes; mise merges additively |
| `ghostty/config` | `?colors` | matugen on Arch, absent elsewhere |

`.zshrc` is not shared — `linux/.zshrc` and `darwin/.zshrc` are separate files.
The Linux one sources `~/.config/zsh/os.zsh` from the same package, then
`~/.config/zsh/local.zsh` for per-machine overrides.

### Adding a distro

1. Add a case to `_resolve_backend` in `lib/pkg.sh` if no existing backend fits.
2. Create `platform/linux/<distro>/packages.txt` and `setup.sh`.
3. Create a `<distro>/` stow package only if a config genuinely differs.

## What's on each machine

| | macOS | Arch |
|---|---|---|
| Shell | fish + tide | zsh + starship |
| Multiplexer | tmux + TPM | [herdr](https://herdr.dev) |
| Window manager | AeroSpace | Hyprland (Lua config) |
| Bar | sketchybar | quickshell |
| Notifications | — | swaync |
| Launcher | Raycast | hyprlauncher, fuzzel for dmenu pickers |
| Display layout | — | nwg-displays |
| Key remapping | Karabiner | — |
| Containers | Colima + docker CLI | native docker |
| Terminal | Ghostty, Kitty | Ghostty |
| Editor | Neovim | Neovim |
| Theming | static TokyoNight Storm | matugen, derived from the wallpaper |

Package counts: 50 formulae, 11 casks and 7 font casks on macOS; 106 repo
packages and 2 AUR packages on Arch. macOS-only: the cloud and infra tooling
(awscli, aws-vault, helm, kubernetes-cli, terraform), the JVM/PHP stack, and
ghostscript + tectonic. Arch-only: the whole Hyprland session, the kernel and
hardware packages, and `arch-audit`.

## Runtimes

[mise](https://mise.jdx.dev/) manages runtimes on both machines.

| Scope | Tools |
|---|---|
| Shared | Node LTS, Python 3.13, Go, Rust, zoxide, lazygit, herdr, `npm:ccstatusline` |
| macOS | Lua 5.5 (SbarLua builds against it), Ruby 3.4.1, Bun |

`auto_install` and `not_found_auto_install` are on; `idiomatic_version_file_enable_tools`
is limited to node. Configs are trusted during setup so shims resolve for
processes that never source a shell rc — systemd units, GUI launchers,
sketchybar.

`ccstatusline` comes through mise's npm backend rather than `npm install -g`,
which would put it in the active node's global prefix and orphan it on a
`node = "lts"` rollover.

## Git

| Setting | Value |
|---|---|
| Signing | SSH format, `allowedSignersFile = ~/.config/git/allowed_signers`, signer from 1Password |
| Identity | `~/work` and `~/dev` → work; `~/personal` and `~/dotfiles` → personal |
| Pull | rebase |
| Default branch | `main` |
| Hooks | `core.hooksPath = ~/.config/git/hooks` |
| Integrity | `fsckObjects` on transfer, fetch and receive |

There is no top-level `user.email` — it comes only from the `includeIf` rules
above, so a repo outside those four directories has no identity and git refuses
to commit. Note that `~/dev` uses the **work** identity.

`core.hooksPath` is global and that directory holds only `pre-commit`, so
repo-local `commit-msg`, `pre-push` and similar hooks (husky, lefthook) are
disabled machine-wide. The `pre-commit` hook chains back to a repo-local one if
it exists.

## Security

| Where | What |
|---|---|
| `system/linux/etc/` | Root-owned drop-ins: sshd hardening, sysctl hardening, faillock, docker daemon |
| `platform/linux/arch/post-link.sh` | ufw default-deny, ssh rate-limited, `system/` tree, `paccache.timer` |
| `lib/system.sh` | Installs those files with `install -D -o root -g root -m 0644`, validates sshd with `sshd -t` before reload |
| `shared/.config/git/hooks/pre-commit` | gitleaks on staged content, global via `core.hooksPath`, chains to repo-local hooks |
| `shared/.gitignore_global` | Credential paths |
| `shared/.ssh/config` | No agent forwarding, hashed known_hosts, keys from the 1Password agent |
| `shared/.claude/settings.json` | Deny rules for credential paths and unrecoverable commands |
| `lib/pkg.sh` | AUR PKGBUILDs are logged before building; everything installs `--noconfirm` |

```bash
./setup.sh --diff-system
```

### Inbound SSH

`system/linux/etc/ssh/sshd_config.d/99-hardening.conf`: `PasswordAuthentication no`,
`AuthenticationMethods publickey`, `PermitRootLogin no`, `AllowUsers nick`,
post-quantum and modern KEX, AEAD ciphers, ETM MACs, ed25519 host keys only, no
forwarding of any kind, `MaxAuthTries 3`, `LoginGraceTime 20`.

`authorize_ssh_keys` writes the agent's public keys to `~/.ssh/authorized_keys`;
`_system_file_allowed` refuses the drop-in while that file is empty.

Restrict ssh to the LAN:

```bash
sudo ufw delete limit 22/tcp
sudo ufw allow from 192.168.0.0/16 to any port 22 proto tcp
```

## Rebuilding this machine

1. Install Arch with [nhalm/arch-install](https://github.com/nhalm/arch-install),
   which lays down the base system this repo assumes: LUKS, btrfs + snapper,
   pipewire audio, NetworkManager, bluetooth and printing. `packages.txt` lists
   only what that does not already provide.
2. Run the one-liner above. No key or account is needed for this.
3. Sign in to 1Password and enable its SSH agent, then re-run `./setup.sh` for
   the ssh hardening. Committing and pulling this repo need the agent too.

Install a package by hand, then add it to `platform/linux/arch/packages.txt`.

## Credits

Hyprland configs written against [ML4W](https://github.com/mylinuxforwork/dotfiles)
by Stephan Raabe as reference. [nhalm/wallpapers](https://github.com/nhalm/wallpapers)
is a subset of [their collection](https://github.com/mylinuxforwork/wallpaper).

## Licence

MIT. Vendored `darwin/.config/sketchybar/` (GPL-3.0) and
`darwin/tmux/plugins/tpm/` (MIT) keep their own.

## Machine-specific / private setup

Host-specific and sensitive setup (backups, sync, vault) lives in the private
`host-setup` repo, not here.
