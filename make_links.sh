#!/usr/bin/env bash
set -euo pipefail

echo "stow-ing configuration"

# Function to safely stow a directory
safe_stow() {
    local package=$1
    echo "Processing $package..."
    
    # Try stow first
    if stow --no "$package" 2>/dev/null; then
        echo "✓ $package: No conflicts, stowing..."
        stow "$package"
    else
        echo "⚠ $package: Conflicts detected, handling..."
        
        # Get list of conflicting files/dirs
        conflicts=$(stow --no "$package" 2>&1 | grep "existing target" | awk '{print $NF}' | sed 's/:$//')
        
        for conflict in $conflicts; do
            target="$HOME/$conflict"
            if [ -e "$target" ]; then
                echo "  Moving existing $target to $target.dotfiles-backup"
                mv "$target" "$target.dotfiles-backup"
            fi
        done
        
        echo "  Retrying stow for $package..."
        stow "$package"
        echo "✓ $package: Successfully stowed after resolving conflicts"
    fi
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
