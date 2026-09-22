#!/usr/bin/env bash
# Steps that are the same everywhere: linking configs, runtimes, shell plugins,
# and the tools we install from their own installers rather than a package manager.

# -------------------------------------------------------------- guards ------

# Guard an optional step on a command, saying so when it is missing: a bare
# `command -v` cannot tell "not installed" from "renamed upstream", and the
# step then vanishes from the log. Extra arguments are alternative names.
have() {
	local c
	for c in "$@"; do
		command -v "$c" >/dev/null 2>&1 && return 0
	done
	echo "  $1 not installed, skipping"
	return 1
}

# ----------------------------------------------------------------- git ------

# Clone/pull a public repo without the global config, so a first install needs
# no credential of any kind. The integrity checks that config carries are
# re-passed here.
git_public() {
	GIT_CONFIG_GLOBAL=/dev/null git \
		-c transfer.fsckobjects=true \
		-c fetch.fsckobjects=true \
		"$@"
}

# ---------------------------------------------------------------- stow ------

# Link one stow package into $HOME.
#
# Any *real* file already sitting at a target path is moved aside to
# <path>.dotfiles-backup first (the .gitignore already covers that suffix).
# This replaces `stow --adopt`, which resolves conflicts the wrong way round:
# it pulls the machine's version *into* the repo, silently overwriting the
# config you were trying to install.
stow_package() {
	local pkg="$1" rel target tdir backup
	[ -d "$DOTFILES/$pkg" ] || return 0
	echo "linking $pkg..."

	while IFS= read -r rel; do
		target="$HOME/$rel"
		[ -e "$target" ] || continue
		[ -L "$target" ] && continue

		# Once stow folds a directory -- ~/.config/nvim becoming a symlink to
		# the package rather than a directory of per-file links -- the files
		# inside it are real files reached *through* that symlink, so the
		# -L test above does not catch them. Backing one up would rename the
		# repo's own file out from under git, so skip any target whose
		# physical directory is already inside the repo.
		# pwd -P rather than readlink -f: POSIX, and works on BSD/macOS.
		tdir=$(cd "$(dirname "$target")" 2>/dev/null && pwd -P) || tdir=""
		case "$tdir/" in
		"$DOTFILES"/*) continue ;;
		esac

		backup="$target.dotfiles-backup"
		if [ -e "$backup" ]; then
			backup="$target.$(date +%Y%m%d-%H%M%S).dotfiles-backup"
		fi
		mv "$target" "$backup"
		echo "  backed up $target -> $backup"
	done < <(cd "$DOTFILES/$pkg" && find . \( -type f -o -type l \) | sed 's|^\./||')

	# --no-folding: link every file individually and keep real directories.
	# A folded directory is a symlink into the repo, so anything written
	# beside a linked file -- a matugen palette, a downloaded theme, a
	# machine-local override -- lands in the working tree.
	stow -d "$DOTFILES" -t "$HOME" -R --no-folding "$pkg"
}

link_configs() {
	local pkg
	while IFS= read -r pkg; do
		[ -n "$pkg" ] && stow_package "$pkg"
	done < <(stow_packages_for_platform "$DOTFILES")
}

# ---------------------------------------------------------------- mise ------

setup_mise() {
	command -v mise >/dev/null 2>&1 || { echo "mise not installed, skipping"; return 0; }

	# Trust before any install or shim resolution. Without this, processes not
	# started from an interactive shell hit "config files are not trusted" on
	# every shim lookup.
	echo "trusting mise config..."
	mise trust "$HOME/.config/mise/config.toml" 2>/dev/null || true
	local f
	for f in "$HOME"/.config/mise/conf.d/*.toml; do
		[ -e "$f" ] && mise trust "$f" 2>/dev/null || true
	done

	echo "installing mise tools..."
	# Don't let one unresolvable tool abort the rest of setup.
	# --yes: mise is otherwise the one backend that can stop and wait for a human.
	# Its npm backend gates low-download packages behind a confirm prompt, which
	# the progress spinner then draws over -- so an unattended run looks hung
	# rather than blocked. pacman/apt/dnf already pass --noconfirm/-y in pkg.sh.
	mise install --yes || echo "  some mise tools failed to install; run 'mise install' for detail"

	# install only fetches what is missing. Without this, re-running setup
	# upgrades brew and pacman packages but leaves every mise tool behind.
	# Stays within the configured ranges: a pin like ruby = "3.4.1" does not
	# move, and nothing rewrites the config -- that is `mise upgrade --bump`,
	# which is a deliberate edit, not a setup step.
	echo "upgrading mise tools..."
	mise upgrade --yes || echo "  some mise tools failed to upgrade; run 'mise upgrade' for detail"
}

# --------------------------------------------------------- zsh plugins ------

# Cloned rather than installed from a package manager so the set is identical on
# every distro and doesn't depend on anyone packaging them.
ZSH_PLUGINS="
zsh-users/zsh-autosuggestions
zsh-users/zsh-completions
zdharma-continuum/fast-syntax-highlighting
"

install_zsh_plugins() {
	command -v zsh >/dev/null 2>&1 || { echo "zsh not installed, skipping plugins"; return 0; }

	local dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
	mkdir -p "$dir"

	local repo name
	for repo in $ZSH_PLUGINS; do
		name="${repo##*/}"
		if [ -d "$dir/$name/.git" ]; then
			echo "  updating $name..."
			git_public -C "$dir/$name" pull --quiet --ff-only || echo "  $name: pull failed, leaving as-is"
		else
			echo "  cloning $name..."
			git_public clone --quiet --depth 1 "https://github.com/$repo" "$dir/$name"
		fi
	done
}

# ------------------------------------------------------ kernel drift --------

check_kernel_drift() {
	[ "$OS_FAMILY" = "linux" ] || return 0
	local running
	running="$(uname -r)"
	[ -d "/usr/lib/modules/$running" ] && return 0

	cat <<-EOF

		  REBOOT NEEDED: the running kernel is $running, and its modules are
		  gone -- an upgrade replaced them. Modules not already loaded cannot
		  load, so container networking and VPNs will fail with errors that do
		  not mention the kernel:

		      failed to add the host <=> sandbox pair interfaces:
		      operation not supported

	EOF
}

# --------------------------------------------------------- ssh access -------

authorize_ssh_keys() {
	local file="$HOME/.ssh/authorized_keys" keys key body added=0

	keys="$(ssh-add -L 2>/dev/null)" || true
	case "$keys" in
	"" | *"no identities"* | *"Could not open"* | *"Error connecting"*)
		echo "no keys available from the ssh agent, skipping"
		echo "  sign in to 1Password and enable its agent, then re-run"
		return 0
		;;
	esac

	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"
	touch "$file"
	chmod 600 "$file"

	while IFS= read -r key; do
		[ -n "$key" ] || continue
		body="$(printf '%s' "$key" | awk '{print $1" "$2}')"
		grep -qF "$body" "$file" && continue
		printf '%s\n' "$key" >>"$file"
		added=$((added + 1))
		echo "  authorised $(printf '%s' "$key" | awk '{print $1, $3, $4, $5}')"
	done <<<"$keys"

	if [ "$added" -eq 0 ]; then
		echo "ssh keys already authorised"
	fi
}

# ---------------------------------------------------------- wallpapers ------

WALLPAPER_REPO="${WALLPAPER_REPO:-https://github.com/nhalm/wallpapers}"

install_wallpapers() {
	local dir="${WALLPAPER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/wallpapers}" legacy state

	legacy="$HOME/Pictures/Wallpapers"

	# ~/Pictures is gated behind a permission prompt on macOS. Move rather than
	# re-clone, and carry the recorded path over.
	if [ ! -e "$dir" ] && [ -d "$legacy/.git" ]; then
		echo "moving wallpapers to $dir..."
		mkdir -p "$(dirname "$dir")"
		mv "$legacy" "$dir"
		state="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
		if [ -f "$state" ]; then
			sed -i.bak "s|$legacy/|$dir/|" "$state"
			rm -f "$state.bak"
		fi
	fi

	if [ -d "$dir/.git" ]; then
		echo "updating wallpapers..."
		git_public -C "$dir" pull --quiet --ff-only || echo "  pull failed, leaving as-is"
		return 0
	fi

	if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
		echo "wallpapers: $dir is not empty and not a clone, leaving it alone"
		echo "  move its contents aside to have setup manage it"
		return 0
	fi

	echo "cloning wallpapers..."
	mkdir -p "$(dirname "$dir")"
	git_public clone --quiet --depth 1 "$WALLPAPER_REPO" "$dir" ||
		echo "  clone failed; the picker will be empty until this succeeds"
}

# ------------------------------------------------------------- zen ----------

# Resolve the profile Zen actually opens. The [Install*] section is
# authoritative: the profile marked Default=1 can be one Zen never uses.
zen_profile_dir() {
	local root="$1" ini="$root/profiles.ini" path
	[ -r "$ini" ] || return 1

	path="$(awk -F= '
		/^\[Install/ { ins = 1; next }
		/^\[/        { ins = 0 }
		ins && $1 == "Default" { print $2; exit }
	' "$ini")"

	[ -n "$path" ] || path="$(awk -F= '
		/^\[/      { path = ""; def = 0 }
		$1 == "Path"    { path = $2 }
		$1 == "Default" && $2 == "1" { def = 1 }
		def && path != "" { print path; exit }
	' "$ini")"

	[ -n "$path" ] || return 1
	case "$path" in
	/*) echo "$path" ;;
	*) echo "$root/$path" ;;
	esac
}

# Zen reads chrome/userChrome.css once, at startup, and only when the legacy
# stylesheet pref is on. matugen renders the palette to state; this points the
# profile at it.
link_zen_theme() {
	local root profile chrome colors userchrome prefs candidate

	root=""
	for candidate in "$HOME/Library/Application Support/zen" "$HOME/.zen"; do
		[ -d "$candidate" ] && { root="$candidate"; break; }
	done
	[ -n "$root" ] || { echo "  zen has no profile yet, skipping theme link"; return 0; }

	profile="$(zen_profile_dir "$root")" || {
		echo "  could not resolve the zen profile, skipping theme link"
		return 0
	}

	colors="${XDG_STATE_HOME:-$HOME/.local/state}/matugen/zen-colors.css"
	chrome="$profile/chrome"
	mkdir -p "$chrome" "$(dirname "$colors")"
	ln -sfn "$colors" "$chrome/zen-matugen.css"

	# An @import has to precede every other rule, so it goes on the front of
	# whatever is already there.
	userchrome="$chrome/userChrome.css"
	if [ ! -e "$userchrome" ]; then
		printf '@import url("zen-matugen.css");\n' >"$userchrome"
	elif ! grep -q 'zen-matugen.css' "$userchrome"; then
		{
			printf '@import url("zen-matugen.css");\n'
			cat "$userchrome"
		} >"$userchrome.tmp" && mv "$userchrome.tmp" "$userchrome"
	fi

	prefs="$profile/user.js"
	if ! grep -q 'legacyUserProfileCustomizations' "$prefs" 2>/dev/null; then
		printf 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\n' >>"$prefs"
	fi

	# Zen serves chrome CSS from a startup cache that it does not invalidate
	# when userChrome.css changes, so a relink without this is invisible until
	# something else happens to rebuild it. The cache sits outside the profile.
	local name cache
	name="$(basename "$profile")"
	for cache in \
		"$HOME/Library/Caches/zen/Profiles/$name/startupCache" \
		"${XDG_CACHE_HOME:-$HOME/.cache}/zen/$name/startupCache"; do
		[ -d "$cache" ] && rm -rf "$cache"
	done

	echo "zen theme linked ($(basename "$profile"))"
}

# The directory Zen reads autoconfig from: the bundle's Resources, or wherever
# the binary lives.
zen_app_dir() {
	[ -d "/Applications/Zen.app/Contents/Resources" ] && {
		echo "/Applications/Zen.app/Contents/Resources"
		return 0
	}
	local bin
	bin="$(command -v zen || command -v zen-browser)" || return 1
	bin="$(readlink -f "$bin" 2>/dev/null || echo "$bin")"
	dirname "$bin"
}

# Copy one file into Zen's install directory.
zen_app_install() {
	local src="$1" rel="$2" dir run=""
	dir="$(zen_app_dir)" || return 1
	[ -w "$dir" ] || run="sudo"
	$run mkdir -p "$dir/$(dirname "$rel")" 2>/dev/null || return 1
	$run cp "$src" "$dir/$rel" 2>/dev/null || return 1
}

# zen-matugen.cfg: without it a palette change only reaches Zen at its next
# start. policies.json: without it Zen updates itself and takes both files with
# it, silently ending the live reload.
install_zen_autoconfig() {
	local src="$DOTFILES/lib/zen"

	zen_app_dir >/dev/null 2>&1 || {
		echo "  zen not installed, skipping live reload"
		return 0
	}

	if zen_app_install "$src/zen-matugen.cfg" "zen-matugen.cfg" &&
		zen_app_install "$src/zen-matugen-prefs.js" "defaults/pref/zen-matugen-prefs.js" &&
		zen_app_install "$src/policies.json" "distribution/policies.json"; then
		echo "zen live reload installed, updates disabled by policy"
	else
		echo "  could not write to Zen's install directory"
		echo "  grant App Management to the terminal in System Settings > Privacy & Security"
	fi
}

# ------------------------------------------------------- login shell --------

# chsh needs the shell listed in /etc/shells; macOS and Linux agree on that much.
set_login_shell() {
	local want="$1" path current
	path="$(command -v "$want" 2>/dev/null)" || { echo "$want not installed, leaving login shell alone"; return 0; }

	# getent is glibc, so it does not exist on macOS. Under `set -o pipefail` the
	# missing command fails the whole pipeline, and the failed assignment then
	# trips `set -e` -- killing setup before the dscl fallback below is reached.
	if command -v getent >/dev/null 2>&1; then
		current="$(getent passwd "$USER" | cut -d: -f7)"
	else
		current=""
	fi
	[ -n "$current" ] || current="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"

	if [ "$current" = "$path" ]; then
		echo "$want is already the login shell"
		return 0
	fi

	if ! grep -qx "$path" /etc/shells 2>/dev/null; then
		echo "adding $path to /etc/shells (may prompt for your password)..."
		echo "$path" | sudo tee -a /etc/shells >/dev/null
	fi
	echo "setting $want as the login shell..."
	chsh -s "$path"
}

# ------------------------------------------------------ external tools ------

install_claude_code() {
	if command -v claude >/dev/null 2>&1; then
		echo "claude code already installed"
		return 0
	fi
	echo "installing claude code..."
	curl -fsSL https://claude.ai/install.sh | bash
}

# Pinned in the shared mise config, so `mise install` above already fetched it.
# This only reports.
# Setup runs before any shell has activated mise, so the shims are not on PATH
# yet. Reach the binary either way.
_herdr() {
	if command -v herdr >/dev/null 2>&1; then
		herdr "$@"
	elif command -v mise >/dev/null 2>&1 && mise which herdr >/dev/null 2>&1; then
		mise exec -- herdr "$@"
	else
		return 127
	fi
}

check_herdr() {
	local v
	# --version prints the name itself, so it is echoed unprefixed.
	if ! v="$(_herdr --version 2>/dev/null)"; then
		echo "herdr not on PATH; see https://herdr.dev/docs/install/"
		return 0
	fi
	echo "${v:-herdr installed}"

	# Validate the config stow just linked, so a bad edit surfaces now rather
	# than at the next herdr start.
	[ -r "$HOME/.config/herdr/config.toml" ] || return 0
	if _herdr config check >/dev/null 2>&1; then
		echo "  config ok"
	else
		echo "  config check FAILED:"
		_herdr config check 2>&1 | sed 's/^/    /'
	fi
}

# herdr-splits provides the nav/resize actions that ~/.config/herdr/config.toml
# binds ctrl+hjkl and alt+hjkl to. Without it those keys dead-end: the nvim
# plugin only covers nvim -> herdr, and `herdr config check` reports a binding
# to a missing plugin as fine.
HERDR_PLUGINS="lmilojevicc/herdr-splits.nvim"

install_herdr_plugins() {
	_herdr --version >/dev/null 2>&1 || return 0

	local repo
	for repo in $HERDR_PLUGINS; do
		if _herdr plugin install "$repo" --yes >/dev/null 2>&1; then
			echo "  ${repo##*/} installed"
		else
			echo "  ${repo##*/} failed to install"
			echo "    ctrl+hjkl will not cross from a herdr pane into nvim"
		fi
	done
}

check_vulnerable_packages() {
	command -v arch-audit >/dev/null 2>&1 || { echo "arch-audit not installed, skipping"; return 0; }
	local out
	out="$(arch-audit --upgradable --quiet 2>/dev/null)" || true
	if [ -z "$out" ]; then
		echo "no packages with known vulnerabilities and an available fix"
	else
		echo "packages with known vulnerabilities that a pacman -Syu would fix:"
		echo "$out" | sed 's/^/  /'
	fi
}

# Import GitHub's web-flow public key so commits made through the GitHub UI
# verify locally. Idempotent: re-importing reports "unchanged".
setup_github_gpg() {
	command -v gpg >/dev/null 2>&1 || { echo "gpg not installed, skipping"; return 0; }
	echo "importing GitHub web-flow GPG key..."
	curl -fsSL https://github.com/web-flow.gpg | gpg --import 2>/dev/null || true
	echo "5DE3E0509C47EA3CF04A42D34AEE18F83AFDEB23:6:" | gpg --import-ownertrust 2>/dev/null || true
}

# The bootstrap clones over https because no SSH key exists yet. Once the
# 1Password agent is configured, switch to SSH so pulls use it.
use_ssh_remote() {
	local url
	url="$(git -C "$DOTFILES" remote get-url origin 2>/dev/null)" || return 0
	case "$url" in
	https://github.com/*)
		echo "switching dotfiles remote to SSH..."
		git -C "$DOTFILES" remote set-url origin "git@github.com:${url#https://github.com/}"
		;;
	esac
}
