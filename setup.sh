#!/usr/bin/env bash
# Full machine setup. Safe to re-run.
#
#   ./setup.sh               install packages, link configs, set up tools
#   ./setup.sh --link-only   just re-link the stow packages
#   ./setup.sh --diff-system show what would change under /etc, change nothing
#
# For a brand new machine use bootstrap.sh instead -- it installs git/stow,
# clones this repo, and calls into here.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES

# shellcheck source=lib/detect.sh
. "$DOTFILES/lib/detect.sh"
# shellcheck source=lib/pkg.sh
. "$DOTFILES/lib/pkg.sh"
# shellcheck source=lib/common.sh
. "$DOTFILES/lib/common.sh"
# shellcheck source=lib/system.sh
. "$DOTFILES/lib/system.sh"

LINK_ONLY=false
[ "${1:-}" = "--link-only" ] && LINK_ONLY=true

detect_platform
_resolve_backend

if [ "${1:-}" = "--diff-system" ]; then
	echo "==> pending changes under /"
	diff_system_files
	exit 0
fi

# Which shell the platform setup wants as the login shell. Overridden below.
LOGIN_SHELL=""

echo "==> $DISTRO ($OS_FAMILY, $CPU_ARCH) -- packages via $PKG_BACKEND"
echo

if [ "$LINK_ONLY" = false ]; then
	# Platform package installs, family first then distro, so a distro script can
	# build on what the family already did.
	while IFS= read -r dir; do
		[ -n "$dir" ] || continue
		if [ -r "$dir/setup.sh" ]; then
			echo "==> ${dir#"$DOTFILES/platform/"} setup"
			# shellcheck disable=SC1091
			. "$dir/setup.sh"
			echo
		fi
	done < <(platform_dirs "$DOTFILES/platform")
fi

# stow comes from the package phase above (it is in every packages.txt). If it
# is missing, something went wrong there -- say so rather than failing per-package.
if ! command -v stow >/dev/null 2>&1; then
	echo "error: stow is not installed, cannot link configs." >&2
	if [ "$LINK_ONLY" = true ]; then
		echo "run ./setup.sh without --link-only first, so packages get installed." >&2
	else
		echo "the package phase should have installed it -- check the errors above." >&2
	fi
	exit 1
fi

echo "==> linking configs"
link_configs
echo

if [ "$LINK_ONLY" = true ]; then
	echo "done (link only)."
	exit 0
fi

# Platform steps that need the stowed configs in place, or that touch services.
while IFS= read -r dir; do
	[ -n "$dir" ] || continue
	if [ -r "$dir/post-link.sh" ]; then
		echo "==> ${dir#"$DOTFILES/platform/"} post-link"
		# shellcheck disable=SC1091
		. "$dir/post-link.sh"
		echo
	fi
done < <(platform_dirs "$DOTFILES/platform")

echo "==> project directories"
mkdir -p "$HOME/personal" "$HOME/work" "$HOME/dev"
echo

echo "==> runtimes"
setup_mise
echo

echo "==> zsh plugins"
install_zsh_plugins
echo

echo "==> agent tooling"
install_claude_code
check_herdr
echo

echo "==> git"
setup_github_gpg
use_ssh_remote
echo

if [ -n "$LOGIN_SHELL" ]; then
	echo "==> login shell"
	set_login_shell "$LOGIN_SHELL"
	echo
fi

echo "Setup complete."
echo "Open a new terminal, then run 'nvim' and ':checkhealth' to verify."
