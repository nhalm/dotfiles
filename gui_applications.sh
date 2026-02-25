#!/usr/bin/env bash
set -euo pipefail

echo "Installing GUI applications (may require password for some apps)..."

# Install GUI applications
brew install --cask --force \
	kitty \
	ghostty \
	cursor \
	brave-browser \
	raycast \
	cleanshot \
	spotify \
	claude \
	chatgpt \
	1password \
	nikitabobko/tap/aerospace

brew install FelixKratz/formulae/sketchybar \
  FelixKratz/formulae/borders

# Install SbarLua framework (required for sketchybar Lua config)
echo "Installing SbarLua framework..."
SBARLUA_TMP="/tmp/SbarLua_$$"
git clone https://github.com/FelixKratz/SbarLua.git "$SBARLUA_TMP"
(cd "$SBARLUA_TMP" && make install)
rm -rf "$SBARLUA_TMP"

# Hide macOS menu bar (sketchybar replaces it)
echo "Hiding macOS menu bar..."
defaults write NSGlobalDomain _HIHideMenuBar -bool true

brew services start felixkratz/formulae/borders
brew services start sketchybar

echo "GUI applications installation complete!"
