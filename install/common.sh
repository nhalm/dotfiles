# Steps shared by macOS and Linux. Sourced by setup.sh.

# Public repos are fetched without the global config, so a first install needs
# no credential; the integrity checks it carries are passed explicitly.
git_public() {
	GIT_CONFIG_GLOBAL=/dev/null git -c transfer.fsckobjects=true -c fetch.fsckobjects=true "$@"
}

sync_repo() {
	local url="$1" dir="$2"
	if [ -d "$dir/.git" ]; then
		echo "updating ${dir/#$HOME/~}"
		git_public -C "$dir" pull --quiet --ff-only || echo "  pull failed, leaving as-is"
	else
		echo "cloning ${url##*/} into ${dir/#$HOME/~}"
		mkdir -p "$(dirname "$dir")"
		git_public clone --quiet --depth 1 "$url" "$dir"
	fi
}

# Links left behind by files deleted or moved in the repo, in the directories
# this package links into.
prune_links() {
	local dir link
	while IFS= read -r dir; do
		[ -d "$HOME/$dir" ] || continue
		while IFS= read -r link; do
			[ -e "$link" ] && continue
			case "$(readlink "$link")" in
			*dotfiles/*) rm "$link" && echo "  removed stale link ${link/#$HOME/~}" ;;
			esac
		done < <(find "$HOME/$dir" -maxdepth 1 -type l)
	done < <(cd "$DOTFILES/$1" && find . \( -type f -o -type l \) -exec dirname {} \; | sed 's|^\.$||; s|^\./||' | sort -u)
}

# Real files in the way are moved to <path>.dotfiles-backup rather than adopted
# into the repo. --no-folding links each file and keeps directories real, so
# anything written beside a linked file stays out of the working tree.
stow_package() {
	local pkg="$1" rel target
	echo "linking $pkg"
	prune_links "$pkg"
	while IFS= read -r rel; do
		target="$HOME/$rel"
		[ -e "$target" ] && [ ! -L "$target" ] || continue
		mv "$target" "$target.dotfiles-backup"
		echo "  backed up ${target/#$HOME/~}"
	done < <(cd "$DOTFILES/$pkg" && find . \( -type f -o -type l \) | sed 's|^\./||')
	stow -d "$DOTFILES" -t "$HOME" -R --no-folding "$pkg"
}

link_configs() {
	stow_package shared
	stow_package "$OS"
}

setup_mise() {
	local f
	for f in "$HOME/.config/mise/config.toml" "$HOME"/.config/mise/conf.d/*.toml; do
		mise trust --quiet "$f"
	done
	mise install --yes || echo "  some mise tools failed; run 'mise install' for detail"
	mise upgrade --yes -x npm:carbonyl || echo "  some mise tools failed to upgrade"
}

install_zsh_plugins() {
	local repo
	for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-completions zdharma-continuum/fast-syntax-highlighting; do
		sync_repo "https://github.com/$repo" "$HOME/.local/share/zsh/plugins/${repo##*/}"
	done
}

install_wallpapers() {
	sync_repo https://github.com/nhalm/wallpapers "$HOME/.local/share/wallpapers"
}

# The profile Zen opens is the one named in an [Install*] section, which can
# differ from the one marked Default=1.
zen_profile_dir() {
	local root="$1" path
	path="$(awk -F= '/^\[Install/ { ins = 1; next } /^\[/ { ins = 0 } ins && $1 == "Default" { print $2; exit }' "$root/profiles.ini" 2>/dev/null)"
	[ -n "$path" ] || return 1
	case "$path" in
	/*) echo "$path" ;;
	*) echo "$root/$path" ;;
	esac
}

# Points the profile's userChrome.css at the matugen palette.
link_zen_theme() {
	local root profile chrome userchrome
	for root in "$HOME/Library/Application Support/zen" "$HOME/.config/zen"; do
		profile="$(zen_profile_dir "$root")" && break
	done
	[ -n "$profile" ] || { echo "zen has no profile yet; re-run after starting it once"; return 0; }

	chrome="$profile/chrome"
	userchrome="$chrome/userChrome.css"
	mkdir -p "$chrome"
	ln -sfn "$HOME/.local/state/matugen/zen-colors.css" "$chrome/zen-matugen.css"
	if ! grep -qs 'zen-matugen.css' "$userchrome"; then
		{ echo '@import url("zen-matugen.css");'; cat "$userchrome" 2>/dev/null; } >"$userchrome.tmp"
		mv "$userchrome.tmp" "$userchrome"
	fi
	grep -qs legacyUserProfileCustomizations "$profile/user.js" ||
		echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >>"$profile/user.js"
	# Zen caches chrome CSS and doesn't notice userChrome.css changing.
	rm -rf "$HOME/Library/Caches/zen/Profiles/${profile##*/}/startupCache" "$HOME/.cache/zen/${profile##*/}/startupCache"
	echo "zen theme linked"
}

install_tools() {
	command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
	# ctrl+hjkl in herdr's config binds to this plugin's actions.
	mise exec -- herdr plugin install lmilojevicc/herdr-splits.nvim --yes >/dev/null 2>&1 ||
		echo "  herdr-splits failed to install"
}

# One passphrase-protected key per machine, for ssh and commit signing.
setup_ssh_key() {
	local key="$HOME/.ssh/id_ed25519" host
	host="$(uname -n | cut -d. -f1)"
	[ -s "$key" ] && return 0
	mkdir -p -m 700 "$HOME/.ssh"
	ssh-keygen -t ed25519 -C "$USER@$host" -f "$key" </dev/tty
	[ "$OS" = macos ] && /usr/bin/ssh-add --apple-use-keychain "$key" </dev/tty
	cat <<-EOF

		Add the key to GitHub for authentication and signing:

		    gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication --title $host
		    gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title $host

	EOF
}

# bootstrap clones over https, before a key exists.
use_ssh_remote() {
	local url
	[ -s "$HOME/.ssh/id_ed25519" ] || return 0
	url="$(git -C "$DOTFILES" remote get-url origin)"
	case "$url" in
	https://github.com/*) git -C "$DOTFILES" remote set-url origin "git@github.com:${url#https://github.com/}" ;;
	esac
}

set_login_shell() {
	local zsh current
	zsh="$(command -v zsh)"
	current="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)" ||
		current="$(dscl . -read "/Users/$USER" UserShell | awk '{print $2}')"
	[ "$current" = "$zsh" ] || chsh -s "$zsh"
}
