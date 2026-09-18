# macOS. Sourced by setup.sh with the lib/ functions available.
#
# GUI applications live in gui.sh, which is run by hand -- several casks prompt
# for a password, so they stay out of the unattended path.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOGIN_SHELL="zsh"

_install_brew() {
	eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
	if command -v brew >/dev/null 2>&1; then
		echo "brew already installed"
		return 0
	fi
	echo "installing brew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	eval "$(/opt/homebrew/bin/brew shellenv)"
}

TAPS="felixkratz/formulae nikitabobko/tap hashicorp/tap"

# Homebrew 6.0+ ignores untrusted third-party taps and warns on every update.
# `brew trust --tap` only records the reference in trust.json -- no disk or
# install check -- so it is idempotent and safe to run before the taps exist.
# Trusting is not tapping, though: without the tap on disk a tap-qualified name
# does not resolve, and brew aborts the whole batch rather than skipping it.
_add_taps() {
	echo "trusting third-party taps..."
	# shellcheck disable=SC2086
	brew trust --tap $TAPS

	echo "tapping..."
	local t
	for t in $TAPS; do
		brew tap "$t"
	done
}

_install_brew
_add_taps

pkg_refresh
brew upgrade || true

pkg_install_file "$HERE/packages.txt"

# Docker CLI client only -- the daemon comes from Colima, so the cask would conflict.
brew install --formula docker

# --adopt keeps this from erroring when the app exists but brew lost track of it
# (which happens after OS upgrades).
brew install --adopt --cask corelocationcli

# shellcheck disable=SC2046
pkg_install_cask $(read_package_list "$HERE/fonts.txt")
