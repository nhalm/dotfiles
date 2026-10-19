#!/usr/bin/env bash
# Set up or update this machine. Shows the plan and asks first; Ctrl-C stops it.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/nhalm/dotfiles/main/setup.sh)
#   ~/dotfiles/setup.sh              packages, links, tools
#   ~/dotfiles/setup.sh --link-only  links only
#
# Process substitution rather than `curl | bash`, which would take the stdin
# that sudo's password prompt needs.

set -euo pipefail
trap 'echo; echo "Stopped." >&2; exit 130' INT

case "$(uname -s)" in
Darwin) OS=macos ;;
Linux) OS=linux ;;
*) echo "unsupported: $(uname -s)" >&2; exit 1 ;;
esac

DOTFILES="$HOME/dotfiles"

confirm() {
	local answer
	read -rp "$1 [y/N] " answer </dev/tty
	[[ "$answer" =~ ^[Yy]$ ]] || { echo "Nothing done."; exit 0; }
}

if [ "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" != "$DOTFILES" ]; then
	echo "Will:"
	if [ "$OS" = macos ]; then
		echo "  install the Xcode Command Line Tools if missing"
	else
		echo "  sudo pacman -Syu git stow base-devel"
	fi
	echo "  clone https://github.com/nhalm/dotfiles into $DOTFILES (if missing)"
	echo "  then run $DOTFILES/setup.sh, which shows its own plan"
	confirm "Continue?"
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
--link-only)
	echo "Will link shared/ and $OS/ into ~ (real files in the way move to <path>.dotfiles-backup; stale links are removed)."
	confirm "Continue?"
	link_configs
	exit 0
	;;
*) echo "usage: setup.sh [--link-only]" >&2; exit 1 ;;
esac

echo "dotfiles for $OS, in order:"
echo "  packages  — $PLAN_PACKAGES"
echo "  links     — shared/ and $OS/ into ~; real files in the way move to <path>.dotfiles-backup; stale links removed"
echo "  $OS     — $PLAN_CONFIGURE"
echo "  tools     — mise install/upgrade, zsh plugins, Claude Code (if missing), herdr-splits plugin"
echo "  ssh       — create ~/.ssh/id_ed25519 (if missing), save its passphrase in Keychain on macOS (if missing), dotfiles remote to ssh, login shell zsh"
echo
confirm "Run all of this?"

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
