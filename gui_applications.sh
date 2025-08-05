#!/usr/bin/env bash
set -euo pipefail

echo "Installing GUI applications (may require password for some apps)..."

# Install GUI applications
brew install --cask --force \
	kitty \
	visual-studio-code \
	cursor \
	brave-browser \
	raycast \
	cleanshot \
	spotify \
	google-drive \
	webex \
	claude-code \
	claude \
	chatgpt

echo "GUI applications installation complete!"