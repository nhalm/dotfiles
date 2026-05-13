#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/restic"

echo "=== Restic Backup Setup ==="
echo

mkdir -p "$CONFIG_DIR"
cp "$SCRIPT_DIR/backup.sh" "$CONFIG_DIR/backup.sh"
cp "$SCRIPT_DIR/restore.sh" "$CONFIG_DIR/restore.sh"
cp "$SCRIPT_DIR/excludes.txt" "$CONFIG_DIR/excludes.txt"
cp "$SCRIPT_DIR/includes.txt" "$CONFIG_DIR/includes.txt"
chmod +x "$CONFIG_DIR/backup.sh" "$CONFIG_DIR/restore.sh"
echo "Copied backup.sh, restore.sh, excludes.txt, and includes.txt to $CONFIG_DIR"

echo
echo "Enter backup target configuration:"

read -p "SFTP user [restic]: " RESTIC_USER
RESTIC_USER="${RESTIC_USER:-restic}"

read -p "Target host (IP or hostname): " RESTIC_TARGET_HOST
if [[ -z "$RESTIC_TARGET_HOST" ]]; then
    echo "Error: Target host is required"
    exit 1
fi

read -p "Target path [/mnt/zpool1/computer_backups]: " RESTIC_TARGET_PATH
RESTIC_TARGET_PATH="${RESTIC_TARGET_PATH:-/mnt/zpool1/computer_backups}"

DEFAULT_HOST=$(hostname -s)
read -p "This computer's backup name [$DEFAULT_HOST]: " RESTIC_HOST_NAME
RESTIC_HOST_NAME="${RESTIC_HOST_NAME:-$DEFAULT_HOST}"

cat > "$CONFIG_DIR/env.sh" << EOF
RESTIC_USER="$RESTIC_USER"
RESTIC_TARGET_HOST="$RESTIC_TARGET_HOST"
RESTIC_TARGET_PATH="$RESTIC_TARGET_PATH"
RESTIC_HOST_NAME="$RESTIC_HOST_NAME"
EOF
chmod 600 "$CONFIG_DIR/env.sh"
echo "Created $CONFIG_DIR/env.sh"

echo
KEYCHAIN_EXISTS=$(security find-generic-password -s restic-backup -a "$USER" >/dev/null 2>&1 && echo "yes" || echo "no")
if [[ "$KEYCHAIN_EXISTS" == "yes" ]]; then
    read -p "Keychain entry exists. Overwrite? [y/N]: " OVERWRITE
    if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
        security delete-generic-password -s restic-backup -a "$USER" 2>/dev/null || true
        read -sp "Enter restic repository password: " RESTIC_PASSWORD
        echo
        security add-generic-password -s restic-backup -a "$USER" -T /usr/bin/security -w "$RESTIC_PASSWORD"
        echo "Updated Keychain entry"
    fi
else
    read -sp "Enter restic repository password: " RESTIC_PASSWORD
    echo
    security add-generic-password -s restic-backup -a "$USER" -T /usr/bin/security -w "$RESTIC_PASSWORD"
    echo "Stored password in Keychain (restic-backup)"
fi

echo
read -p "Initialize restic repository? (skip if already exists) [y/N]: " INIT_REPO
if [[ "$INIT_REPO" =~ ^[Yy]$ ]]; then
    echo "Initializing repository..."
    "$CONFIG_DIR/backup.sh" init
    echo "Repository initialized."
fi

echo
read -p "Setup daily backup schedule? [Y/n]: " SETUP_LAUNCHD
if [[ ! "$SETUP_LAUNCHD" =~ ^[Nn]$ ]]; then
    "$SCRIPT_DIR/install_scheduled.sh"
fi

echo
echo "=== Setup Complete ==="
echo
echo "Commands:"
echo "  $CONFIG_DIR/backup.sh backup      # Run backup now"
echo "  $CONFIG_DIR/backup.sh snapshots   # List this host's snapshots"
echo "  $CONFIG_DIR/restore.sh            # Interactive restore"
echo "  $CONFIG_DIR/backup.sh mount       # Browse backups via FUSE"
