#!/usr/bin/env bash
# One-shot bootstrap for a brand new machine:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/nhalm/dotfiles/main/bootstrap.sh)
#
# Use process substitution rather than `curl … | bash`: piping ties up stdin,
# which breaks the sudo password prompt the package installs need.
#
# Installs only enough to clone this repo (git, stow, a compiler toolchain),
# then hands off to setup.sh for everything else.

set -euo pipefail

REPO_HTTPS="https://github.com/nhalm/dotfiles.git"
DOTFILES="${DOTFILES:-$HOME/dotfiles}"

die() { echo "error: $*" >&2; exit 1; }

detect() {
	case "$(uname -s)" in
	Darwin) FAMILY=darwin; ID=macos ;;
	Linux)
		FAMILY=linux
		[ -r /etc/os-release ] || die "no /etc/os-release; cannot identify this distro"
		# shellcheck disable=SC1091
		ID="$(. /etc/os-release && echo "${ID:-unknown}")"
		LIKE="$(. /etc/os-release && echo "${ID_LIKE:-}")"
		;;
	*) die "unsupported platform: $(uname -s)" ;;
	esac
}

install_prereqs() {
	local d
	case "$ID" in
	macos) : ;;
	arch | cachyos | endeavouros | manjaro | garuda) d=pacman ;;
	debian | ubuntu | pop | linuxmint) d=apt ;;
	fedora | rhel | centos | rocky | almalinux) d=dnf ;;
	*)
		for x in ${LIKE:-}; do
			case "$x" in
			arch) d=pacman; break ;;
			debian | ubuntu) d=apt; break ;;
			fedora | rhel) d=dnf; break ;;
			esac
		done
		;;
	esac

	case "${d:-}" in
	pacman)
		echo "==> installing prerequisites (pacman)"
		sudo pacman -Sy --needed --noconfirm git stow base-devel
		;;
	apt)
		echo "==> installing prerequisites (apt)"
		sudo apt-get update && sudo apt-get install -y git stow build-essential curl
		;;
	dnf)
		echo "==> installing prerequisites (dnf)"
		sudo dnf install -y git stow @development-tools curl
		;;
	"")
		[ "$ID" = macos ] || die "no prerequisite installer for '$ID'; add one to bootstrap.sh"
		;;
	esac

	if [ "$ID" = macos ]; then
		# Command Line Tools provide git; Homebrew and stow come from setup.sh.
		xcode-select -p >/dev/null 2>&1 || {
			echo "==> installing Xcode Command Line Tools (follow the GUI prompt, then re-run)"
			xcode-select --install
			exit 1
		}
	fi
}

clone() {
	if [ -d "$DOTFILES/.git" ]; then
		echo "==> $DOTFILES already exists, pulling"
		git -C "$DOTFILES" pull --ff-only || echo "  pull failed, continuing with what's on disk"
	else
		echo "==> cloning into $DOTFILES"
		# https on purpose: no SSH key exists yet. setup.sh flips the remote to
		# SSH at the end, once the 1Password agent is in play.
		git clone "$REPO_HTTPS" "$DOTFILES"
	fi
}

detect
install_prereqs
clone
echo
exec "$DOTFILES/setup.sh"
