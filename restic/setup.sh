#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/restic"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.restic.backup.plist"

echo "=== Restic Backup Setup ==="
echo

mkdir -p "$CONFIG_DIR"
cp "$SCRIPT_DIR/backup.sh" "$CONFIG_DIR/backup.sh"
cp "$SCRIPT_DIR/excludes.txt" "$CONFIG_DIR/excludes.txt"
cp "$SCRIPT_DIR/includes.txt" "$CONFIG_DIR/includes.txt"
chmod +x "$CONFIG_DIR/backup.sh"
echo "Copied backup.sh, excludes.txt, and includes.txt to $CONFIG_DIR"

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
KEYCHAIN_EXISTS=$(security find-generic-password -s restic-backup -a "$USER" 2>/dev/null && echo "yes" || echo "no")
if [[ "$KEYCHAIN_EXISTS" == "yes" ]]; then
    read -p "Keychain entry exists. Overwrite? [y/N]: " OVERWRITE
    if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
        security delete-generic-password -s restic-backup -a "$USER" 2>/dev/null || true
        read -sp "Enter restic repository password: " RESTIC_PASSWORD
        echo
        security add-generic-password -s restic-backup -a "$USER" -w "$RESTIC_PASSWORD"
        echo "Updated Keychain entry"
    fi
else
    read -sp "Enter restic repository password: " RESTIC_PASSWORD
    echo
    security add-generic-password -s restic-backup -a "$USER" -w "$RESTIC_PASSWORD"
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
    read -p "Backup hour (0-23) [10]: " BACKUP_HOUR
    BACKUP_HOUR="${BACKUP_HOUR:-10}"

    launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    mkdir -p "$(dirname "$LAUNCHD_PLIST")"

    cat > "$LAUNCHD_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.restic.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>$CONFIG_DIR/backup.sh</string>
        <string>backup</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$BACKUP_HOUR</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$CONFIG_DIR/backup.log</string>
    <key>StandardErrorPath</key>
    <string>$CONFIG_DIR/backup.log</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

    launchctl load "$LAUNCHD_PLIST"
    echo "Scheduled daily backup at ${BACKUP_HOUR}:00"
fi

echo
echo "=== Setup Complete ==="
echo
echo "Commands:"
echo "  $CONFIG_DIR/backup.sh backup      # Run backup now"
echo "  $CONFIG_DIR/backup.sh snapshots   # List this host's snapshots"
echo "  $CONFIG_DIR/backup.sh mount       # Browse backups"
