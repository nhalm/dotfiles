#!/usr/bin/env fish

# Platform detection function
function _get_platform
    set unameOut (uname -s)
    switch $unameOut
        case Linux
            echo "Linux"
        case Darwin
            echo "Mac"
        case 'CYGWIN*'
            echo "Cygwin"
        case 'MINGW*'
            echo "MinGw"
        case '*'
            echo "UNKNOWN:$unameOut"
    end
end

set -gx PLATFORM (_get_platform)

# Editor configuration
set -gx EDITOR nvim
set -gx VISUAL nvim

# Go configuration
set -gx GOPATH $HOME/go
if not test -d $GOPATH
    mkdir -p $GOPATH/src
    mkdir -p $GOPATH/bin
end

# Essential aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Neovim aliases
if command -v nvim > /dev/null
    alias vi='nvim'
    alias vim='nvim'
end

# Platform-specific setup
if test "$PLATFORM" = "Mac"
    # Homebrew setup
    eval (/opt/homebrew/bin/brew shellenv)
    
    # Yarn global bin (if yarn is available)
    if command -v yarn > /dev/null
        fish_add_path (yarn global bin)
    end
    
    # glocate setup
    if command -v glocate > /dev/null
        alias locate="glocate -d $HOME/locatedb"
        if test -f "$HOME/locatedb"
            set -gx LOCATE_PATH "$HOME/locatedb"
        end
    end
    alias loaddb="gupdatedb --localpaths=$HOME --prunepaths=/Volumes --output=$HOME/locatedb"
end

# Add Go and other paths
fish_add_path /usr/local/go/bin
fish_add_path $GOPATH/bin

# History configuration (fish has good defaults, but we can customize)
set -U fish_history_max_entries 10000

# pyenv setup (if available)
if command -v pyenv > /dev/null
    pyenv init - | source
    if command -v pyenv-virtualenv-init > /dev/null
        pyenv virtualenv-init - | source
    end
end

# nvm setup (fish has its own nvm plugin that's better)
# We'll set this up separately if needed