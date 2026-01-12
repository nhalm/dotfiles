#!/bin/bash

# Claude Code Tokyo Night themed status line script
# Displays segments: project | git_branch | model | context_usage

input=$(cat)
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_id=$(echo "$input" | jq -r '.model.id')
model_name=$(echo "$input" | jq -r '.model.display_name')
transcript_path=$(echo "$input" | jq -r '.transcript_path')

# Tokyo Night Moon Palette - EXACT copy from tmux-tokyo-night/src/palletes/moon.sh
# All color definitions exactly as in the original theme
BG_DARK_HEX="#1e2030"
BG_HEX="#222436"
BG_HIGHLIGHT_HEX="#2f334d"
TERMINAL_BLACK_HEX="#444a73"
FG_HEX="#c8d3f5"
FG_DARK_HEX="#828bb8"
FG_GUTTER_HEX="#3b4261"
DARK3_HEX="#545c7e"
COMMENT_HEX="#7a88cf"
DARK5_HEX="#737aa2"
BLUE0_HEX="#3e68d7"
BLUE_HEX="#82aaff"
CYAN_HEX="#86e1fc"
BLUE1_HEX="#65bcff"
BLUE2_HEX="#0db9d7"
BLUE5_HEX="#89ddff"
BLUE6_HEX="#b4f9f8"
BLUE7_HEX="#394b70"
PURPLE_HEX="#fca7ea"
MAGENTA2_HEX="#ff007c"
MAGENTA_HEX="#c099ff"
ORANGE_HEX="#ff966c"
YELLOW_HEX="#ffc777"
GREEN_HEX="#c3e88d"
GREEN1_HEX="#4fd6be"
GREEN2_HEX="#41a6b5"
TEAL_HEX="#4fd6be"
RED_HEX="#ff757f"
RED1_HEX="#c53b53"
WHITE_HEX="#ffffff"

# Convert to ANSI escape codes - Background colors
BG_DARK=$'\033[48;2;30;32;48m'        # #1e2030
BG=$'\033[48;2;34;36;54m'             # #222436
BG_HIGHLIGHT=$'\033[48;2;47;51;77m'   # #2f334d
TERMINAL_BLACK=$'\033[48;2;68;71;115m' # #444a73
BG_BLUE0=$'\033[48;2;62;104;215m'     # #3e68d7
BG_BLUE=$'\033[48;2;130;170;255m'     # #82aaff
BG_CYAN=$'\033[48;2;134;225;252m'     # #86e1fc
BG_BLUE1=$'\033[48;2;101;188;255m'    # #65bcff
BG_BLUE2=$'\033[48;2;13;185;215m'     # #0db9d7
BG_BLUE5=$'\033[48;2;137;221;255m'    # #89ddff
BG_BLUE6=$'\033[48;2;180;249;248m'    # #b4f9f8
BG_BLUE7=$'\033[48;2;57;75;112m'      # #394b70
BG_PURPLE=$'\033[48;2;252;167;234m'   # #fca7ea
BG_MAGENTA2=$'\033[48;2;255;0;124m'   # #ff007c
BG_MAGENTA=$'\033[48;2;192;153;255m'  # #c099ff
BG_ORANGE=$'\033[48;2;255;150;108m'   # #ff966c
BG_YELLOW=$'\033[48;2;255;199;119m'   # #ffc777
BG_GREEN=$'\033[48;2;195;232;141m'    # #c3e88d
BG_GREEN1=$'\033[48;2;79;214;190m'    # #4fd6be
BG_GREEN2=$'\033[48;2;65;166;181m'    # #41a6b5
BG_TEAL=$'\033[48;2;79;214;190m'      # #4fd6be
BG_RED=$'\033[48;2;255;117;127m'      # #ff757f
BG_RED1=$'\033[48;2;197;59;83m'       # #c53b53
BG_WHITE=$'\033[48;2;255;255;255m'    # #ffffff

# Convert to ANSI escape codes - Foreground colors
FG_DARK=$'\033[38;2;30;32;48m'        # #1e2030
FG=$'\033[38;2;200;211;245m'          # #c8d3f5
FG_DARK_SHADE=$'\033[38;2;130;139;184m' # #828bb8
FG_GUTTER=$'\033[38;2;59;66;97m'      # #3b4261
FG_DARK3=$'\033[38;2;84;92;126m'      # #545c7e
FG_COMMENT=$'\033[38;2;122;136;207m'  # #7a88cf
FG_DARK5=$'\033[38;2;115;122;162m'    # #737aa2
FG_BLUE0=$'\033[38;2;62;104;215m'     # #3e68d7
FG_BLUE=$'\033[38;2;130;170;255m'     # #82aaff
FG_CYAN=$'\033[38;2;134;225;252m'     # #86e1fc
FG_BLUE1=$'\033[38;2;101;188;255m'    # #65bcff
FG_BLUE2=$'\033[38;2;13;185;215m'     # #0db9d7
FG_BLUE5=$'\033[38;2;137;221;255m'    # #89ddff
FG_BLUE6=$'\033[38;2;180;249;248m'    # #b4f9f8
FG_BLUE7=$'\033[38;2;57;75;112m'      # #394b70
FG_PURPLE=$'\033[38;2;252;167;234m'   # #fca7ea
FG_MAGENTA2=$'\033[38;2;255;0;124m'   # #ff007c
FG_MAGENTA=$'\033[38;2;192;153;255m'  # #c099ff
FG_ORANGE=$'\033[38;2;255;150;108m'   # #ff966c
FG_YELLOW=$'\033[38;2;255;199;119m'   # #ffc777
FG_GREEN=$'\033[38;2;195;232;141m'    # #c3e88d
FG_GREEN1=$'\033[38;2;79;214;190m'    # #4fd6be
FG_GREEN2=$'\033[38;2;65;166;181m'    # #41a6b5
FG_TEAL=$'\033[38;2;79;214;190m'      # #4fd6be
FG_RED=$'\033[38;2;255;117;127m'      # #ff757f
FG_RED1=$'\033[38;2;197;59;83m'       # #c53b53
FG_WHITE=$'\033[38;2;255;255;255m'    # #ffffff

RESET=$'\033[0m'

# Tokyo Night powerline separators - matching your tmux theme
LEFT_SEP=$'\xee\x82\xb2'   # Left powerline triangle 
RIGHT_SEP=$'\xee\x82\xb0'  # Right powerline triangle 

# Function to get context limits based on model ID
get_context_limit() {
    case "$1" in
        *"claude-3-5-sonnet"*) echo 200000 ;;
        *"claude-3-5-haiku"*) echo 200000 ;;
        *"claude-3-opus"*) echo 200000 ;;
        *"claude-3-sonnet"*) echo 200000 ;;
        *"claude-3-haiku"*) echo 200000 ;;
        *"sonnet-4"*) echo 500000 ;;
        *"claude-2.1"*) echo 200000 ;;
        *"claude-2.0"*) echo 100000 ;;
        *"claude-instant"*) echo 100000 ;;
        *) echo 200000 ;;
    esac
}

# Get context usage
get_context_usage() {
    if [[ -f "$transcript_path" ]]; then
        local char_count=$(wc -c < "$transcript_path" 2>/dev/null || echo 0)
        echo $((char_count / 4))
    else
        echo 0
    fi
}

# Format numbers with K/M suffixes
format_number() {
    local num=$1
    if [ $num -gt 1000000 ]; then
        printf "%.1fM" $(echo "scale=1; $num / 1000000" | bc -l 2>/dev/null || echo "$(($num / 1000000))")
    elif [ $num -gt 1000 ]; then
        printf "%.1fK" $(echo "scale=1; $num / 1000" | bc -l 2>/dev/null || echo "$(($num / 1000))")
    else
        echo $num
    fi
}

# Calculate context information
context_limit=$(get_context_limit "$model_id")
context_used=$(get_context_usage)
context_percentage=$((context_used * 100 / context_limit))

# Get project and git info
project_name=$(basename "$current_dir")
git_info=""
if [ -d "$current_dir/.git" ]; then
    cd "$current_dir"
    git_branch=$(git branch --show-current 2>/dev/null || echo 'detached')
    git_info="$git_branch"
fi

# Format context usage with color
context_used_fmt=$(format_number $context_used)
context_limit_fmt=$(format_number $context_limit)

# Choose context segment color based on usage - using exact tmux theme colors
if [ $context_percentage -gt 90 ]; then
    CONTEXT_BG=$BG_RED      # red background
    CONTEXT_FG=$FG_RED      # red foreground for arrow
elif [ $context_percentage -gt 75 ]; then
    CONTEXT_BG=$BG_YELLOW   # yellow background  
    CONTEXT_FG=$FG_YELLOW   # yellow foreground for arrow
else
    CONTEXT_BG=$BG_BLUE7    # blue7 background (dark blue like other plugins)
    CONTEXT_FG=$FG_BLUE7    # blue7 foreground for arrow
fi

# Build Tokyo Night Moon powerline segments - using EXACT tmux theme combinations
output=""

# Segment 1: Project folder (like session segment in tmux)
# Using FG_DARK_SHADE for text on light green
output+="${BG_GREEN}${FG_DARK_SHADE} ${project_name} ${RESET}"
output+="${FG_GREEN}${RIGHT_SEP}${RESET} "

if [ -n "$git_info" ]; then
    # Git branch segment (like plugin segment in tmux)
    # tmux plugins use: bg=blue7 (dark blue), fg=white
    output+="${BG_BLUE7}${FG_WHITE} ${git_info} ${RESET}"
    output+="${FG_BLUE7}${RIGHT_SEP}${RESET} "
fi

# Model segment (like active window in tmux)
# tmux active window uses: bg=magenta, fg=white
output+="${BG_MAGENTA}${FG_WHITE} ${model_name} ${RESET}"
output+="${FG_MAGENTA}${RIGHT_SEP}${RESET} "

# Context usage segment (like plugin segment in tmux)
# tmux plugins use: bg=blue7/blue0/red/yellow, fg=white
if [ $context_percentage -gt 75 ]; then
    # High usage: red or yellow background with white text
    output+="${CONTEXT_BG}${FG_WHITE} ${context_used_fmt}/${context_limit_fmt} (${context_percentage}%) ${RESET}"
else
    # Normal usage: dark blue background with white text (like plugins)
    output+="${CONTEXT_BG}${FG_WHITE} ${context_used_fmt}/${context_limit_fmt} (${context_percentage}%) ${RESET}"
fi

# Add closing arrow after last segment
output+="${CONTEXT_FG}${RIGHT_SEP}${RESET}"

printf "%s" "$output"