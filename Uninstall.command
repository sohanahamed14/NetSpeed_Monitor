#!/bin/bash
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.netspeed.plist"
INSTALL_DIR="$HOME/.netspeed"

echo "==========================================="
echo "   Uninstalling Menu Bar NetSpeed Monitor  "
echo "==========================================="

# Stop launchctl service and kill process
launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x netspeed 2>/dev/null || true

# Remove files
rm -f "$PLIST_PATH"
rm -rf "$INSTALL_DIR"

echo ""
echo "✅ NetSpeed has been completely removed from your Mac."
echo "You can close this window."
exit 0
