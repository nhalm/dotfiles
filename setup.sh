#!/usr/bin/env bash
# Set up or update this machine. Safe to re-run.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/nhalm/dotfiles/main/setup.sh)
#   ~/dotfiles/setup.sh              packages, links, tools
#   ~/dotfiles/setup.sh --link-only  links only
#
# Process substitution rather than `curl | bash`, which would take the stdin
# that sudo's password prompt needs.

set -euo pipefail

case "$(uname -s)" in
Darwin) OS=macos ;;
Linux) OS=linux ;;
*) echo "unsupported: $(uname -s)" >&2; exit 1 ;;
esac

DOTFILES="$HOME/dotfiles"

if [ "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" != "$DOTFILES" ]; then
	if [ "$OS" = macos ]; then
		xcode-select -p >/dev/null 2>&1 || { xcode-select --install; echo "re-run once the Command Line Tools are installed"; exit 1; }
	else
		sudo pacman -Syu --needed --noconfirm git stow base-devel
	fi
	[ -d "$DOTFILES/.git" ] || git clone https://github.com/nhalm/dotfiles.git "$DOTFILES"
	exec "$DOTFILES/setup.sh" "$@"
fi

. "$DOTFILES/install/common.sh"
. "$DOTFILES/install/$OS.sh"

case "${1:-}" in
"") ;;
--link-only) link_configs; exit 0 ;;
*) echo "usage: setup.sh [--link-only]" >&2; exit 1 ;;
esac

echo "==> packages"
install_packages
echo "==> links"
link_configs
echo "==> $OS"
configure
echo "==> tools"
mkdir -p "$HOME/personal" "$HOME/work" "$HOME/dev" "$HOME/.local/state/psql"
setup_mise
install_zsh_plugins
install_tools
echo "==> ssh"
setup_ssh_key
use_ssh_remote
set_login_shell

echo "Done. Open a new terminal."
