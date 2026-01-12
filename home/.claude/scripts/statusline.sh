#!/bin/bash

# Claude Code Status Line Script
# Displays project info and cost information from ccusage

# Read JSON input from stdin
input=$(cat)

# Extract basic information
folder=$(basename "$(echo "$input" | jq -r '.workspace.current_dir')")
model=$(echo "$input" | jq -r '.model.display_name')

# Detect project type and language info
lang_info=""

# Check for Python project (venv exists or Python files present)
if [ -n "$VIRTUAL_ENV" ]; then
    # Python project with virtual environment
    venv_raw=$(echo "${VIRTUAL_ENV##*/}" | sed 's/-[0-9].*//')
    if [ "$venv_raw" = ".venv" ] || [ "$venv_raw" = "venv" ]; then
        venv="($folder)"
    else
        venv="($venv_raw)"
    fi
    pyver=$(python3 --version 2>/dev/null | cut -d' ' -f2 || echo 'N/A')
    lang_info=" | 💼 $venv | 🐍 $pyver"
elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ]; then
    # Python project without venv
    pyver=$(python3 --version 2>/dev/null | cut -d' ' -f2 || echo 'N/A')
    lang_info=" | 🐍 $pyver"
elif [ -f "go.mod" ] || [ -f "go.sum" ] || ls *.go >/dev/null 2>&1; then
    # Go project
    gover=$(go version 2>/dev/null | grep -oE 'go[0-9]+\.[0-9]+(\.[0-9]+)?' | sed 's/go//' || echo 'N/A')
    if [ "$gover" != "N/A" ]; then
        lang_info=" | 🦫 $gover"
    fi
fi

# Git branch
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')

# Base status line with existing information
base_status="📁 $folder${lang_info} | 🌿 $branch | 🤖 $model"

# Try to get ccusage information
cost_info=""
if command -v bun >/dev/null 2>&1; then
    # Get session ID for additional data
    session_id=$(echo "$input" | jq -r '.session_id // empty')
    
    # Use ccusage statusline command which is designed for this purpose
    ccusage_output=$(echo "$input" | bun x ccusage statusline 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$ccusage_output" ]; then
        # Parse ccusage statusline output format: 🤖 Model | 💰 session / daily / block (time left) | 🔥 rate
        
        # Extract session cost (before "session")
        session_cost=$(echo "$ccusage_output" | grep -oE '\$[0-9]+\.[0-9]+ session|N/A session' | sed 's/ session//')
        
        # Extract daily cost (before "today")
        daily_cost=$(echo "$ccusage_output" | grep -oE '\$[0-9]+\.[0-9]+ today' | sed 's/ today//')
        
        # Extract block cost (before "block")
        block_cost=$(echo "$ccusage_output" | grep -oE '\$[0-9]+\.[0-9]+ block' | sed 's/ block//')
        
        # Extract time remaining (inside parentheses)
        time_left=$(echo "$ccusage_output" | grep -oE '[0-9]+h [0-9]+m left')
        
        # Get token data from ccusage blocks --active for session cost and time remaining
        blocks_json=$(bun x ccusage blocks --active --json 2>/dev/null)
        if [ -n "$blocks_json" ]; then
            # Get the actual session cost from JSON data
            json_session_cost=$(echo "$blocks_json" | jq -r '.blocks[0].costUSD // empty' 2>/dev/null)
            
            # Override session cost with JSON data if available and more accurate
            if [ -n "$json_session_cost" ] && [ "$json_session_cost" != "null" ]; then
                session_cost="\$$(printf "%.2f" "$json_session_cost")"
            fi
            
            # Get remaining minutes from projection
            remaining_minutes=$(echo "$blocks_json" | jq -r '.blocks[0].projection.remainingMinutes // empty' 2>/dev/null)
            if [ -n "$remaining_minutes" ] && [ "$remaining_minutes" != "null" ] && [ "$remaining_minutes" != "0" ]; then
                hours=$((remaining_minutes / 60))
                mins=$((remaining_minutes % 60))
                time_left="${hours}h ${mins}m left"
            fi
        fi
        
        # Build cost information string
        cost_parts=()
        
        # Show session cost if available and not N/A, otherwise show block cost
        if [ -n "$session_cost" ] && [ "$session_cost" != "N/A" ] && [ "$session_cost" != "" ]; then
            cost_parts+=("💸 $session_cost")
        elif [ -n "$block_cost" ] && [ "$block_cost" != "" ]; then
            # Show block cost as session cost if no session cost available
            cost_parts+=("💸 $block_cost")
        fi
        
        if [ -n "$daily_cost" ]; then
            cost_parts+=("💰 $daily_cost/day")
        fi
        
        if [ -n "$time_left" ]; then
            cost_parts+=("⏱️ $time_left")
        fi
        
        # Join cost parts with " | "
        if [ ${#cost_parts[@]} -gt 0 ]; then
            cost_info=" | "
            for i in "${!cost_parts[@]}"; do
                if [ $i -gt 0 ]; then
                    cost_info="${cost_info} | "
                fi
                cost_info="${cost_info}${cost_parts[$i]}"
            done
        fi
    fi
fi

# Output the complete status line
echo "${base_status}${cost_info}"
