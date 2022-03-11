#!/usr/bin/env bash

echo "stow-ing configuration"

case "$(uname -s)" in
    Linux*)
	;;
    Darwin*)
	eval "$(/opt/homebrew/bin/brew shellenv)"
	stow iterm2
	;;
    CYGWIN*) echo "cygwin not supported";;
    MINGW*) echo "MinGw not supported";;
	*)      echo "$(uname -s)  not supported"
esac


stow nvim
stow home
stow starship
