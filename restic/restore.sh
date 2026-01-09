#!/bin/bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/restic"
ENV_FILE="$CONFIG_DIR/env.sh"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: $ENV_FILE not found. Run setup.sh first."
    exit 1
fi

source "$ENV_FILE"

export RESTIC_REPOSITORY="sftp:${RESTIC_USER}@${RESTIC_TARGET_HOST}:${RESTIC_TARGET_PATH}"
export RESTIC_PASSWORD_COMMAND="security find-generic-password -s restic-backup -a $USER -w"

SFTP_CMD="ssh -i $HOME/.ssh/restic ${RESTIC_USER}@${RESTIC_TARGET_HOST} -s sftp"

run_restic() {
    restic -o sftp.command="$SFTP_CMD" "$@"
}

has_fzf() {
    command -v fzf &>/dev/null
}

select_with_fzf() {
    local prompt="$1"
    fzf --height=40% --reverse --prompt="$prompt "
}

select_with_numbers() {
    local prompt="$1"
    local -a items
    local i=1

    while IFS= read -r line; do
        items+=("$line")
        echo "  [$i] $line" >&2
        ((i++))
    done

    echo >&2
    read -rp "$prompt [1-$((i-1))]: " choice >&2

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice < i)); then
        echo "${items[$((choice-1))]}"
    else
        echo "Invalid selection" >&2
        return 1
    fi
}

select_item() {
    local prompt="$1"
    if has_fzf; then
        select_with_fzf "$prompt"
    else
        select_with_numbers "$prompt"
    fi
}

multi_select_with_fzf() {
    local prompt="$1"
    fzf --height=40% --reverse --multi --prompt="$prompt " \
        --header="TAB to select multiple, ENTER to confirm"
}

multi_select_with_numbers() {
    local prompt="$1"
    local -a items
    local i=1

    while IFS= read -r line; do
        items+=("$line")
        echo "  [$i] $line" >&2
        ((i++))
    done

    echo >&2
    echo "Enter numbers separated by spaces, or 'all' for everything:" >&2
    read -rp "$prompt: " choices >&2

    if [[ "$choices" == "all" ]]; then
        printf '%s\n' "${items[@]}"
        return 0
    fi

    for choice in $choices; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice < i)); then
            echo "${items[$((choice-1))]}"
        fi
    done
}

multi_select_item() {
    local prompt="$1"
    if has_fzf; then
        multi_select_with_fzf "$prompt"
    else
        multi_select_with_numbers "$prompt"
    fi
}

check_connectivity() {
    if ! nc -z -w 5 "$RESTIC_TARGET_HOST" 22 2>/dev/null; then
        echo "Error: Backup target $RESTIC_TARGET_HOST not reachable."
        exit 1
    fi
}

select_snapshot() {
    echo "Fetching snapshots..."
    local snapshots
    snapshots=$(run_restic snapshots --json | jq -r '.[] | "\(.short_id)  \(.time | split("T")[0])  \(.hostname)  \(.paths | join(", ") | .[0:50])"')

    if [[ -z "$snapshots" ]]; then
        echo "No snapshots found."
        exit 1
    fi

    echo "Select a snapshot:"
    local selected
    selected=$(echo "$snapshots" | select_item "snapshot>")

    if [[ -z "$selected" ]]; then
        echo "No snapshot selected."
        exit 1
    fi

    echo "$selected" | awk '{print $1}'
}

browse_snapshot() {
    local snapshot_id="$1"
    local current_path="/"
    local selected_paths=()

    while true; do
        echo
        echo "Current path: $current_path"
        echo "Selected for restore: ${#selected_paths[@]} items"
        echo

        local contents
        contents=$(run_restic ls "$snapshot_id" "$current_path" --json 2>/dev/null | jq -r 'select(.struct_type == "node") | "\(.type | .[0:1])  \(.name)"' | head -100)

        if [[ -z "$contents" ]]; then
            echo "Empty or invalid path."
            current_path="/"
            continue
        fi

        local menu_items
        menu_items=$(printf '%s\n%s\n%s\n%s\n%s' \
            "[..] Go up" \
            "[+] Add current path to restore" \
            "[>] Restore selected items" \
            "[q] Quit" \
            "$contents")

        echo "Navigate or select items:"
        local choice
        choice=$(echo "$menu_items" | select_item "browse>")

        case "$choice" in
            "[..] Go up")
                current_path=$(dirname "$current_path")
                [[ "$current_path" == "." ]] && current_path="/"
                ;;
            "[+] Add current path to restore")
                selected_paths+=("$current_path")
                echo "Added: $current_path"
                ;;
            "[>] Restore selected items")
                if [[ ${#selected_paths[@]} -eq 0 ]]; then
                    echo "No items selected. Add paths first with [+]."
                else
                    do_restore "$snapshot_id" "${selected_paths[@]}"
                    return
                fi
                ;;
            "[q] Quit")
                echo "Cancelled."
                exit 0
                ;;
            d\ *)
                local dir_name="${choice#d  }"
                if [[ "$current_path" == "/" ]]; then
                    current_path="/$dir_name"
                else
                    current_path="$current_path/$dir_name"
                fi
                ;;
            f\ *)
                local file_name="${choice#f  }"
                local file_path
                if [[ "$current_path" == "/" ]]; then
                    file_path="/$file_name"
                else
                    file_path="$current_path/$file_name"
                fi
                selected_paths+=("$file_path")
                echo "Added: $file_path"
                ;;
            *)
                echo "Unknown selection"
                ;;
        esac
    done
}

do_restore() {
    local snapshot_id="$1"
    shift
    local paths=("$@")

    echo
    echo "Items to restore:"
    printf '  %s\n' "${paths[@]}"
    echo

    read -rp "Restore to original locations? [Y/n]: " restore_original

    local target_path=""
    if [[ "${restore_original,,}" == "n" ]]; then
        read -rp "Enter target directory: " target_path
        target_path="${target_path/#\~/$HOME}"
        mkdir -p "$target_path"
    fi

    read -rp "Proceed with restore? [y/N]: " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Cancelled."
        exit 0
    fi

    local include_args=()
    for p in "${paths[@]}"; do
        include_args+=(--include "$p")
    done

    echo "Restoring..."
    if [[ -n "$target_path" ]]; then
        run_restic restore "$snapshot_id" --target "$target_path" "${include_args[@]}"
    else
        run_restic restore "$snapshot_id" --target "/" "${include_args[@]}"
    fi

    echo "Restore complete."
}

quick_restore() {
    local snapshot_id="$1"
    local target="${2:-.}"

    target="${target/#\~/$HOME}"

    echo "Restoring snapshot $snapshot_id to $target..."
    run_restic restore "$snapshot_id" --target "$target"
    echo "Restore complete."
}

usage() {
    cat <<EOF
Usage: $0 [command] [options]

Commands:
    (no args)       Interactive mode - browse and select files to restore
    quick <id>      Restore entire snapshot to current directory
    quick <id> <p>  Restore entire snapshot to specified path

Examples:
    $0              Start interactive restore
    $0 quick abc123 Restore snapshot abc123 to current directory
    $0 quick abc123 ~/restored  Restore to ~/restored
EOF
}

main() {
    check_connectivity

    case "${1:-}" in
        quick)
            if [[ -z "${2:-}" ]]; then
                echo "Error: snapshot ID required"
                usage
                exit 1
            fi
            quick_restore "$2" "${3:-}"
            ;;
        -h|--help|help)
            usage
            ;;
        "")
            local snapshot_id
            snapshot_id=$(select_snapshot)
            echo "Selected snapshot: $snapshot_id"
            browse_snapshot "$snapshot_id"
            ;;
        *)
            echo "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
