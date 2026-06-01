#!/bin/zsh
set -e

LABEL="com.ss.codex-traffic-light"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_VALUE="$(id -u)"

launchctl bootout "gui/$UID_VALUE/$LABEL" >/dev/null 2>&1 || true
rm -f "$PLIST"

echo "开机自启已卸载：$LABEL"
