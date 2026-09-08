# system/

Config that lives outside `$HOME`.

Everything else in this repo is linked into `$HOME` by stow. That does not work
for `/etc`: those files are root-owned, and symlinking them at a path inside a
user-writable git repo would mean anything that can write the repo can rewrite
root's config. A compromised dependency, a bad `git checkout`, or an agent with
write access to `~/dotfiles` would silently own the machine.

So these are **copied** into place with `sudo install -o root -g root -m 0644`,
by `install_system_files` in `lib/system.sh`, called from the Arch
`post-link.sh`. Copies are only made when content actually differs, so a re-run
with nothing to change needs no password at all.

    ./setup.sh --diff-system    # show what would change under /, change nothing

The tree mirrors the destination:

    system/linux/etc/sysctl.d/99-hardening.conf  ->  /etc/sysctl.d/99-hardening.conf

`*.md` files are skipped, so documentation can sit next to what it describes.

## What is here

| File | Does |
|---|---|
| `etc/sysctl.d/99-hardening.conf` | Kernel hardening. Only the settings Arch does *not* already get right, and an explicit list of what is deliberately left alone. |
| `etc/ssh/sshd_config.d/99-hardening.conf` | Key-only auth, no root login, modern KEX/cipher/MAC. Inert unless sshd is enabled. |
| `etc/docker/daemon.json` | Publishes container ports to loopback by default — see below. |
| `etc/security/faillock.conf` | Explicit lockout policy for failed logins, including the lock screen. |

### One caveat: package-owned files

`sysctl.d/`, `sshd_config.d/` and `docker/daemon.json` are drop-ins or files no
package owns, so nothing ever fights us for them. `security/faillock.conf` is
different — the `pam` package ships it and there is no drop-in directory. When
`pam` upgrades, pacman notices the file changed and writes a `.pacnew` beside
it rather than reverting it. Reconcile those with `pacdiff` (pacman-contrib,
already installed). Prefer a drop-in wherever the tool offers one; this is the
only file here that cannot use one.

## Docker does not go through ufw

Published container ports are DNAT'd in the `nat` table
and traverse `FORWARD`, while ufw's default-deny lives in `INPUT` — so
`docker run -p 8080:80` is reachable from every machine on the LAN even though
`ufw status` says deny incoming. This surprises people regularly and is the
single most likely way this laptop accidentally serves something.

Setting the daemon's default publish address to loopback means `-p 8080:80`
binds `127.0.0.1:8080` instead of `0.0.0.0:8080`. Exposing a container to the
network then has to be deliberate:

    docker run -p 0.0.0.0:8080:80 ...   # explicit, on purpose

### Deliberately not set in daemon.json

- `"icc": false` — isolates containers on the *default* bridge. compose files
  use user-defined networks and are unaffected, but a plain
  `docker run` postgres that another `docker run` container talks to would
  break, with a confusing connection error rather than a clear one.
- `"no-new-privileges": true` — a good per-container flag, a poor daemon-wide
  default: it breaks any image relying on a setuid binary (`ping`, `sudo`).
  Prefer `--security-opt no-new-privileges` on containers you control.
- `"userns-remap"` — strongest isolation available, but it breaks bind-mount
  ownership, which is how most local dev containers get source code.
