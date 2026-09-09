#!/usr/bin/env bash
# GUI applications for macOS. Run by hand -- several of these prompt for a
# password, which is why they are not part of ./setup.sh.
#
#   ./platform/darwin/gui.sh

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
# shellcheck disable=SC2046
brew install --cask --force $(read_package_list "$HERE/casks.txt")

brew install \
	FelixKratz/formulae/sketchybar \
	FelixKratz/formulae/borders

# SbarLua is the Lua binding sketchybar's config is written against; it has no
# formula, so it is built from source.
echo "installing SbarLua..."
tmp="$(mktemp -d)"
git_public clone https://github.com/FelixKratz/SbarLua.git "$tmp/SbarLua"
(cd "$tmp/SbarLua" && make install)
rm -rf "$tmp"

# sketchybar replaces the system menu bar.
echo "hiding the macOS menu bar..."
defaults write NSGlobalDomain _HIHideMenuBar -bool true

brew services start felixkratz/formulae/borders
brew services start sketchybar

echo "GUI installation complete."
