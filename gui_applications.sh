#!/usr/bin/env bash
set -euo pipefail

echo "Installing GUI applications (may require password for some apps)..."

# Install GUI applications
brew install --cask --force \
	kitty \
  ghostty \
	visual-studio-code \
	cursor \
	brave-browser \
	raycast \
	cleanshot \
	spotify \
	google-drive \
	claude-code \
	claude \
	chatgpt \
	1password \
	aerospace

brew tap FelixKratz/formulae
brew install sketchybar \
  boarders

echo "GUI applications installation complete!"
