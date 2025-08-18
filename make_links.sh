#!/usr/bin/env bash
set -euo pipefail

echo "stow-ing configuration"

# Function to stow a directory, removing existing files
safe_stow() {
    local package=$1
    echo "Processing $package..."
    
    # Force stow with --adopt to handle conflicts by adopting existing files
    echo "✓ $package: Stowing with --adopt to handle any conflicts..."
    stow --adopt "$package"
}

case "$(uname -s)" in
    Linux*)
	;;
    Darwin*)
	eval "$(/opt/homebrew/bin/brew shellenv)"
	;;
    CYGWIN*) echo "cygwin not supported";;
    MINGW*) echo "MinGw not supported";;
	*)      echo "$(uname -s)  not supported"
esac


safe_stow home
safe_stow bin
