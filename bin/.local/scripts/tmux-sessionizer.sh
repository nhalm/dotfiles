#!/usr/bin/env zsh
set -euo pipefail

if [[ $# -eq 1 ]]; then
    selected=$1
else
    # Find all git repositories in common directories (up to 2 levels deep)
    git_repos=$(find ~/dev ~/Downloads ~/Documents -maxdepth 3 -type d -name .git 2>/dev/null | sed 's/\/.git$//' | sort -u || true)
    
    # Find regular directories (1 level deep)
    regular_dirs=$(find ~/dev ~/Downloads ~/Documents -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -u || true)
    
    # Combine all directories
    all_options=$(echo -e "$git_repos\n$regular_dirs" | grep -v '^$' | sort -u)
    
    # Use fzf with preview
    selected=$(echo "$all_options" | fzf --preview 'ls -la {} 2>/dev/null | head -20' --preview-window=right:50%:wrap)
fi

if [[ -z $selected ]]; then
    exit 0
fi

# Create session name from directory path
selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux || true)

# Check if we're not in tmux and tmux isn't running at all
if [[ -z ${TMUX:-} ]] && [[ -z $tmux_running ]]; then
    tmux new-session -s $selected_name -c $selected
    exit 0
fi

# Only create new session if it doesn't exist
if ! tmux has-session -t=$selected_name 2> /dev/null; then
    tmux new-session -ds $selected_name -c $selected
fi

# If we're inside tmux, switch to the session
# If we're outside tmux, attach to the session
if [[ -n ${TMUX:-} ]]; then
    tmux switch-client -t $selected_name
else
    tmux attach-session -t $selected_name
fi
