#!/usr/bin/env bash

echo "stow-ing configuration"

eval "$(/opt/homebrew/bin/brew shellenv)"

stow nvim
stow home
stow iterm2
stow starship
