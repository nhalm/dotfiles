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
EXCLUDE_FILE="$CONFIG_DIR/excludes.txt"
INCLUDE_FILE="$CONFIG_DIR/includes.txt"

run_restic() {
    restic -o sftp.command="$SFTP_CMD" "$@"
}

get_backup_paths() {
    grep -v '^#' "$INCLUDE_FILE" | grep -v '^$' | sed "s|^~|$HOME|"
}

case "${1:-backup}" in
    backup)
        echo "Starting backup for host: ${RESTIC_HOST_NAME:-$(hostname -s)}..."
        run_restic backup \
            --host "${RESTIC_HOST_NAME:-$(hostname -s)}" \
            --exclude-file="$EXCLUDE_FILE" \
            --exclude-caches \
            --files-from <(get_backup_paths)

        echo "Cleaning up old snapshots..."
        run_restic forget \
            --host "${RESTIC_HOST_NAME:-$(hostname -s)}" \
            --keep-daily 7 \
            --prune

        echo "Backup complete."
        ;;
    snapshots)
        run_restic snapshots --host "${RESTIC_HOST_NAME:-$(hostname -s)}"
        ;;
    snapshots-all)
        run_restic snapshots
        ;;
    restore)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 restore <snapshot-id> [target-path]"
            exit 1
        fi
        run_restic restore "$2" --target "${3:-.}"
        ;;
    mount)
        MOUNT_POINT="${2:-/tmp/restic-mount}"
        mkdir -p "$MOUNT_POINT"
        echo "Mounting at $MOUNT_POINT (Ctrl+C to unmount)"
        run_restic mount "$MOUNT_POINT"
        ;;
    init)
        run_restic init
        ;;
    *)
        run_restic "$@"
        ;;
esac
