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

brew services start felixkratz/formulae/borders
brew services start sketchybar

echo "GUI applications installation complete!"
