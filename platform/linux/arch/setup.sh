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

	echo
	echo "--- PKGBUILD for yay ---"
	cat "$tmp/yay/PKGBUILD"
	echo "--- end PKGBUILD ---"
	echo

	(cd "$tmp/yay" && makepkg -si --noconfirm)
	rm -rf "$tmp"
}

pkg_refresh
pkg_install_file "$HERE/packages.txt"

_install_yay

# shellcheck disable=SC2046
pkg_install_aur $(read_package_list "$HERE/aur.txt")
