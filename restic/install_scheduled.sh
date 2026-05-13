#!/bin/bash
set -euo pipefail

CONFIG_DIR="$HOME/.config/restic"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.restic.backup.plist"

if [[ ! -x "$CONFIG_DIR/backup.sh" ]]; then
    echo "Error: $CONFIG_DIR/backup.sh not found. Run setup.sh first."
    exit 1
fi

BACKUP_HOUR="${1:-}"
if [[ -z "$BACKUP_HOUR" ]]; then
    read -p "Backup hour (0-23) [10]: " BACKUP_HOUR
    BACKUP_HOUR="${BACKUP_HOUR:-10}"
fi

if ! [[ "$BACKUP_HOUR" =~ ^[0-9]+$ ]] || (( BACKUP_HOUR < 0 || BACKUP_HOUR > 23 )); then
    echo "Error: BACKUP_HOUR must be an integer 0-23 (got: $BACKUP_HOUR)"
    exit 1
fi

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
