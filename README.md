# dotfiles

Personal configuration for macOS and Arch Linux, linked with GNU stow.

| Doc | Covers |
|---|---|
| [docs/linux.md](docs/linux.md) | Arch: Hyprland, the quickshell bar, notifications, theming, monitors, scripts, zsh |
| [docs/macos.md](docs/macos.md) | macOS: AeroSpace, sketchybar, Karabiner, zsh, GUI applications |
| [docs/neovim.md](docs/neovim.md) | Neovim: layout, plugins, keymaps — shared by both machines |
| [docs/herdr.md](docs/herdr.md) | herdr: the multiplexer on both machines |

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
three anonymous clones of public repos setup performs on itself — the zsh
plugins, wallpapers and SbarLua. GitHub authenticates every ssh connection
whether the repo is public or not, so on a machine with no key those three
would fail. They go through `git_public`, which drops the global config for that one
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
| `shared` | zsh, nvim, git, ssh, mise, ghostty, lazygit, herdr, psqlrc, gitleaks, ccstatusline, claude, portable matugen templates |
| `darwin` | aerospace, sketchybar, karabiner, matugen, `.local/scripts`, git and zsh OS fragments |
| `linux` | git and zsh OS fragments |
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
| `mise/config.toml` | `mise/conf.d/*.toml` | every tool, per scope; mise merges additively |
| `ghostty/config` | `?colors` | matugen on both machines; the include is optional, so it is absent until matugen has run |
| `.zshrc` | `~/.config/zsh/os.zsh` | per-OS agent socket, ls flags, aliases |

`.zshrc` sources its OS fragment *before* `compinit`, so a package can extend
`fpath` — that is how Homebrew's `site-functions` reach completion on macOS. It
then sources `~/.config/zsh/local.zsh` last, for per-machine overrides that are
gitignored.

`.zprofile` is shared too. It guards the one macOS-only line it needs
(`[[ -x /opt/homebrew/bin/brew ]] && eval "$(brew shellenv)"`) rather than
carrying a second fragment for a single command.

### Adding a distro

1. Add a case to `_resolve_backend` in `lib/pkg.sh` if no existing backend fits.
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
| Theming | matugen, derived from an image | matugen, derived from the wallpaper |

Package counts: 50 formulae, 9 casks and 7 font casks on macOS; 106 repo
packages and 2 AUR packages on Arch. macOS-only: the cloud and infra tooling
(awscli, aws-vault, helm, kubernetes-cli, terraform), the JVM/PHP stack, and
ghostscript + tectonic. Arch-only: the whole Hyprland session, the kernel and
hardware packages, and `arch-audit`.

## Runtimes

[mise](https://mise.jdx.dev/) manages runtimes on both machines.

Every tool lives in `~/.config/mise/conf.d/`, so the full set reads in one
directory; `config.toml` carries nothing but `[settings]`.

| File | Package | Tools |
|---|---|---|
| `conf.d/shared.toml` | `shared` | Node 24, Go 1, Rust 1, zoxide, lazygit, herdr, `npm:ccstatusline` |
| `conf.d/darwin.toml` | `darwin` | Lua 5.5 (SbarLua builds against it), Ruby 3, Bun, `cargo:matugen`, `npm:carbonyl`, `npm:@mermaid-js/mermaid-cli`, `npm:ccusage` |

The split is not cosmetic: a stow package is what decides which machine gets a
file. `cargo:matugen` in particular must stay out of `shared` — Arch installs
matugen from pacman, and a second copy from crates.io would be picked
inconsistently, because `.zprofile` appends the mise shims (so non-interactive
callers get pacman's) while `mise activate` prepends them (so interactive
shells get mise's).

Every tool names a major version rather than `latest` or an exact build, so
`mise upgrade` picks up patches and minors but never crosses a major. Two
cannot: `lua` stays on 5.5 because SbarLua builds against it, and `carbonyl`
names an exact build because it publishes nothing but prereleases, which mise
filters out of a range.

There is no global python: it shadows the distro interpreter, so it is pinned
per project instead.

`auto_install` and `not_found_auto_install` are on; `idiomatic_version_file_enable_tools`
is limited to node. Configs are trusted during setup so shims resolve for
processes that never source a shell rc — systemd units, GUI launchers,
sketchybar.

### Which installer owns a tool

**Never `npm install -g`, bare `cargo install`, or `pip install --user`.** Those
prefixes belong to the *active* runtime, and mise swaps runtimes per directory
and on every `lts` rollover, so anything installed that way is orphaned without
a word. Two questions decide the rest: does the system package manager carry
it, and do both machines need to agree on the version.

| Kind of thing | Goes to | Examples |
|---|---|---|
| Language runtime | mise | node, go, rust, ruby, lua, bun |
| Same version needed on both machines | shared mise config | herdr, lazygit, zoxide, `npm:ccstatusline` |
| Compiled tool the system package manager carries | `packages.txt` | ripgrep, fzf, jq, neovim, starship, chafa |
| Tool it does *not* carry, but a language registry does | mise registry backend, per-OS `conf.d` | `cargo:matugen`, `npm:ccusage` |
| GUI application | `casks.txt` | ghostty, raycast, 1password |

The second row is why `lazygit` and `zoxide` sit in mise even though brew and
pacman both package them: pinning there stops one machine drifting a version
ahead of the other. `starship` is in `packages.txt` instead because only macOS
needed it — pacman already covers Arch, and prompt drift is harmless.

Prefer the package manager where it has the tool. mise's `npm:` and `cargo:`
backends resolve or compile at install time — `cargo:matugen` builds for ~25s,
`npm:@mermaid-js/mermaid-cli` resolves 265 packages — where brew pours a
prebuilt bottle in about a second.

Two traps in the registry backends:

- They filter prereleases out of `latest`. A package that only ever publishes
  prereleases resolves to an empty list and fails outright, so it needs an exact
  version — which is why `carbonyl` is pinned.
- Scoped npm names work as written (`npm:@mermaid-js/mermaid-cli`).

### Updating

`./setup.sh` upgrades everything: `brew upgrade` on macOS, `pacman -Syu` on
Arch, and `mise upgrade` for the runtimes. `mise install` alone only fetches
what is *missing*, which is why the upgrade is a separate call — without it a
re-run would move the system packages forward and leave every mise tool behind.

By hand:

| Command | Does |
|---|---|
| `mise outdated` | what is behind, within its configured range |
| `mise upgrade` | move those forward; `mise upgrade zoxide` for one |
| `mise outdated --bump` | what is newer but outside the range — a major bump, e.g. `node = "24"` while 26 is out |
| `mise upgrade --bump` | rewrites the config to the newer range, then upgrades |

`--bump` edits `config.toml`, which is a symlink into this repo, so it belongs
in a commit rather than in setup.

mise holds back releases younger than 24h (`minimum_release_age`), so a tool
published yesterday reports as up to date until the window passes. That is a
supply-chain guard, not a bug.

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

MIT. Vendored `darwin/.config/sketchybar/` (GPL-3.0) keeps its own.

## Machine-specific / private setup

Host-specific and sensitive setup (backups, sync, vault) lives in the private
`host-setup` repo, not here.
