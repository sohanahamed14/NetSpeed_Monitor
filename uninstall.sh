#!/bin/bash
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.netspeed.plist"
INSTALL_DIR="$HOME/.netspeed"

echo "==========================================="
echo "   Uninstalling NetSpeed Monitor           "
echo "==========================================="

launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x netspeed 2>/dev/null || true

rm -f "$PLIST_PATH"
rm -rf "$INSTALL_DIR"

echo "✅ NetSpeed removed successfully."
