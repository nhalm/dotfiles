#!/usr/bin/env bash
# GUI applications for macOS. Run by setup.sh unless --no-gui, and standalone:
#
#   ./platform/darwin/gui.sh
#
# Several casks prompt for a password.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${DOTFILES:-$(cd "$HERE/../.." && pwd)}"

# shellcheck source=../../lib/detect.sh
. "$DOTFILES/lib/detect.sh"
# shellcheck source=../../lib/pkg.sh
. "$DOTFILES/lib/pkg.sh"
# shellcheck source=../../lib/common.sh
. "$DOTFILES/lib/common.sh"

detect_platform
_resolve_backend
[ "$OS_FAMILY" = "darwin" ] || { echo "gui.sh is macOS-only" >&2; exit 1; }

echo "installing GUI applications (may prompt for a password)..."
# No --force: it reinstalls every cask on every run. Already-installed ones are
# skipped here and moved forward by the `brew upgrade` in setup.sh.
# shellcheck disable=SC2046
brew install --cask $(read_package_list "$HERE/casks.txt") || true

brew install \
	FelixKratz/formulae/sketchybar \
	FelixKratz/formulae/borders

# SbarLua is the Lua binding sketchybar's config is written against; it has no
# formula, so it is built from source. Skipped once built -- the build takes
# half a minute and this script runs on every setup. Delete the .so to rebuild.
SBARLUA="$HOME/.local/share/sketchybar_lua/sketchybar.so"
if [ -f "$SBARLUA" ]; then
	echo "SbarLua already built"
else
	echo "installing SbarLua..."
	tmp="$(mktemp -d)"
	git_public clone https://github.com/FelixKratz/SbarLua.git "$tmp/SbarLua"
	(cd "$tmp/SbarLua" && make install)
	rm -rf "$tmp"
fi

# sketchybar replaces the system menu bar.
echo "hiding the macOS menu bar..."
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# Already-running services report a warning rather than restarting.
brew services start felixkratz/formulae/borders || true
brew services start sketchybar || true

echo "GUI installation complete."
