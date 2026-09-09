#!/usr/bin/env bash
# Package-manager abstraction. Each distro contributes a backend here plus a
# flat packages.txt under platform/; nothing else in the repo needs to know
# which package manager is in play.
#
# Adding a distro that an existing backend already covers (a derivative, say)
# costs nothing -- _resolve_backend falls back to ID_LIKE.

PKG_BACKEND=""

_resolve_backend() {
	local d
	case "$DISTRO" in
	macos) PKG_BACKEND="brew" ;;
	arch | cachyos | endeavouros | manjaro | garuda) PKG_BACKEND="pacman" ;;
	debian | ubuntu | pop | linuxmint | raspbian) PKG_BACKEND="apt" ;;
	fedora | rhel | centos | rocky | almalinux) PKG_BACKEND="dnf" ;;
	*)
		for d in $DISTRO_LIKE; do
			case "$d" in
			arch) PKG_BACKEND="pacman" ; break ;;
			debian | ubuntu) PKG_BACKEND="apt" ; break ;;
			fedora | rhel) PKG_BACKEND="dnf" ; break ;;
			esac
		done
		;;
	esac

	if [ -z "$PKG_BACKEND" ]; then
		echo "no package backend for DISTRO='$DISTRO' (ID_LIKE='$DISTRO_LIKE')." >&2
		echo "add a case to _resolve_backend in lib/pkg.sh and a packages.txt under platform/." >&2
		return 1
	fi
}

# Read a packages.txt: one package per line, '#' comments and blanks ignored.
read_package_list() {
	local file="$1"
	[ -r "$file" ] || return 0
	sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$file"
}

pkg_refresh() {
	case "$PKG_BACKEND" in
	brew) brew update ;;
	# -Syu, never a bare -Sy: syncing the db then installing without an
	# upgrade is a partial upgrade, which breaks a rolling release.
	pacman) sudo pacman -Syu --noconfirm ;;
	apt) sudo apt-get update ;;
	dnf) sudo dnf -y makecache ;;
	esac
}

# Install packages, skipping any already present. Safe to re-run.
pkg_install() {
	[ $# -gt 0 ] || return 0
	case "$PKG_BACKEND" in
	brew) brew install "$@" ;;
	pacman) sudo pacman -S --needed --noconfirm "$@" ;;
	apt) sudo apt-get install -y "$@" ;;
	dnf) sudo dnf install -y "$@" ;;
	esac
}

# Install from the AUR (or the family equivalent). A no-op where there isn't one,
# so callers don't have to guard.
#
# An AUR PKGBUILD is arbitrary shell that runs as you at build time, from a
# repo any user can upload to, so yay's diff prompt is left in place as the
# checkpoint against a hijacked or typosquatted package.
#
# Set DOTFILES_AUR_NOCONFIRM=1 for an unattended rebuild of a machine you
# already trust the package set on.
pkg_install_aur() {
	[ $# -gt 0 ] || return 0
	local confirm=()
	[ "${DOTFILES_AUR_NOCONFIRM:-0}" = "1" ] && confirm=(--noconfirm)
	case "$PKG_BACKEND" in
	pacman) yay -S --needed "${confirm[@]}" "$@" ;;
	*) echo "  no AUR equivalent on $PKG_BACKEND, skipping: $*" ;;
	esac
}

pkg_install_cask() {
	[ $# -gt 0 ] || return 0
	case "$PKG_BACKEND" in
	brew) brew install --cask "$@" ;;
	*) echo "  casks are macOS-only, skipping: $*" ;;
	esac
}

# Install every package listed in the given packages.txt files that exist.
pkg_install_file() {
	local file pkgs
	for file in "$@"; do
		pkgs="$(read_package_list "$file")"
		[ -n "$pkgs" ] || continue
		echo "installing from ${file##*/}..."
		# shellcheck disable=SC2086
		pkg_install $pkgs
	done
}
