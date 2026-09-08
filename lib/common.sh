#!/usr/bin/env bash
# Steps that are the same everywhere: linking configs, runtimes, shell plugins,
# and the tools we install from their own installers rather than a package manager.

# ---------------------------------------------------------------- stow ------

# Link one stow package into $HOME.
#
# Any *real* file already sitting at a target path is moved aside to
# <path>.dotfiles-backup first (the .gitignore already covers that suffix).
# This replaces `stow --adopt`, which resolves conflicts the wrong way round:
# it pulls the machine's version *into* the repo, silently overwriting the
# config you were trying to install.
stow_package() {
	local pkg="$1" rel target tdir
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

		mv "$target" "$target.dotfiles-backup"
		echo "  backed up $target -> $target.dotfiles-backup"
	done < <(cd "$DOTFILES/$pkg" && find . \( -type f -o -type l \) | sed 's|^\./||')

	stow -d "$DOTFILES" -t "$HOME" -R "$pkg"
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
	mise install || echo "  some mise tools failed to install; run 'mise install' for detail"
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
			git -C "$dir/$name" pull --quiet --ff-only || echo "  $name: pull failed, leaving as-is"
		else
			echo "  cloning $name..."
			git clone --quiet --depth 1 "https://github.com/$repo" "$dir/$name"
		fi
	done
}

# ------------------------------------------------------- login shell --------

# chsh needs the shell listed in /etc/shells; macOS and Linux agree on that much.
set_login_shell() {
	local want="$1" path current
	path="$(command -v "$want" 2>/dev/null)" || { echo "$want not installed, leaving login shell alone"; return 0; }

	current="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"
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

# herdr is the agent runtime that replaces tmux here: persistent agent sessions,
# panes/tabs, and git worktree management. It is pinned in the shared mise
# config, so `mise install` above already fetched it -- this only reports.
check_herdr() {
	if command -v herdr >/dev/null 2>&1; then
		echo "herdr $(herdr --version 2>/dev/null || echo installed)"
	else
		echo "herdr not on PATH; see https://herdr.dev/docs/install/"
	fi
}

# npm globals, installed against the mise-managed node. `mise exec` is used
# rather than a bare `npm` because setup runs before any shell has activated
# mise, so the shims are not on PATH yet.
install_npm_globals() {
	[ $# -gt 0 ] || return 0
	if ! command -v mise >/dev/null 2>&1; then
		echo "mise not installed, skipping npm globals"
		return 0
	fi
	local pkg
	for pkg in "$@"; do
		if mise exec node -- npm list -g "$pkg" >/dev/null 2>&1; then
			echo "  updating $pkg..."
			mise exec node -- npm update -g "$pkg" || echo "  $pkg update failed"
		else
			echo "  installing $pkg..."
			mise exec node -- npm install -g "$pkg" || echo "  $pkg install failed"
		fi
	done
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
# 1Password agent is configured, switch to SSH so pulls use it -- and so the
# insteadOf rewrite in .gitconfig isn't doing it invisibly.
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
