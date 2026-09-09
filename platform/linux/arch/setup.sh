# Arch (and derivatives that resolve here via ID_LIKE).
# Sourced by setup.sh with lib/ available; $HERE is this directory.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# yay builds AUR packages; it is itself only in the AUR, so bootstrap it by hand.
_install_yay() {
	if command -v yay >/dev/null 2>&1; then
		echo "yay already installed"
		return 0
	fi
	echo "installing yay..."
	local tmp
	tmp="$(mktemp -d)"
	git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"

	# Show the PKGBUILD before building it. This is the one AUR package we
	# install without yay's own diff prompt available (yay is what provides
	# it), so it is the one that most needs a human to look.
	echo
	echo "--- PKGBUILD for yay (review before it is built) ---"
	cat "$tmp/yay/PKGBUILD"
	echo "--- end PKGBUILD ---"
	echo
	if [ "${DOTFILES_AUR_NOCONFIRM:-0}" != "1" ]; then
		printf 'build and install yay from the above PKGBUILD? [y/N] '
		read -r reply </dev/tty
		case "$reply" in
		[yY] | [yY][eE][sS]) ;;
		*)
			echo "skipping yay; AUR packages will not be installed."
			rm -rf "$tmp"
			return 0
			;;
		esac
	fi

	(cd "$tmp/yay" && makepkg -si --noconfirm)
	rm -rf "$tmp"
}

pkg_refresh
pkg_install_file "$HERE/packages.txt"

_install_yay

# shellcheck disable=SC2046
pkg_install_aur $(read_package_list "$HERE/aur.txt")
