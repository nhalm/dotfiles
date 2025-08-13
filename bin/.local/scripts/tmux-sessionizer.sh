#!/usr/bin/env zsh
set -euo pipefail

if [[ $# -eq 1 ]]; then
    selected=$1
else
    # Find all git repositories in common directories (up to 2 levels deep)
    git_repos=$(find ~/dev ~/Downloads ~/Documents -maxdepth 3 -type d -name .git 2>/dev/null | sed 's/\/.git$//' | sort -u || true)
    
    # Find regular directories (1 level deep)
    regular_dirs=$(find ~/dev ~/Downloads ~/Documents ~/ -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -u || true)
    
    # Combine all directories and add "Create new session" option
    all_options=$(echo -e "$git_repos\n$regular_dirs" | grep -v '^$' | sort -u)
    all_options=$(echo -e "Create new session...\n$all_options")
    
    # Use fzf with preview
    selected=$(echo "$all_options" | fzf --preview 'test "{}" = "Create new session..." && echo "Create a new tmux session without a directory" || ls -la "{}" 2>/dev/null | head -20' --preview-window=right:50%:wrap)
fi

if [[ -z $selected ]]; then
    exit 0
fi

# Handle "Create new session" option
if [[ $selected == "Create new session..." ]]; then
    echo -n "Enter session name: "
    read session_name
    if [[ -z $session_name ]]; then
        echo "No session name provided, exiting."
        exit 0
    fi
    selected_name=$(echo "$session_name" | tr . _ | tr ' ' _)
    selected=""  # No directory for this session
else
    # Create session name from directory path
    selected_name=$(basename "$selected" | tr . _)
fi

tmux_running=$(pgrep tmux || true)

# Check if we're not in tmux and tmux isn't running at all
if [[ -z ${TMUX:-} ]] && [[ -z $tmux_running ]]; then
    if [[ -n $selected ]]; then
        tmux new-session -s $selected_name -c $selected
    else
        tmux new-session -s $selected_name
    fi
    exit 0
fi

# Only create new session if it doesn't exist
if ! tmux has-session -t=$selected_name 2> /dev/null; then
    if [[ -n $selected ]]; then
        tmux new-session -ds $selected_name -c $selected
    else
        tmux new-session -ds $selected_name
    fi
fi

# If we're inside tmux, switch to the session
# If we're outside tmux, attach to the session
if [[ -n ${TMUX:-} ]]; then
    tmux switch-client -t $selected_name
else
    tmux attach-session -t $selected_name
fi
