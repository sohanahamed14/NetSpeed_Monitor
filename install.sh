#!/bin/bash
set -e

INSTALL_DIR="$HOME/.netspeed"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.netspeed.plist"
RAW_BASE="https://raw.githubusercontent.com/sohanahamed14/Mac-Tools/main"

echo "==========================================="
echo "   Installing NetSpeed Monitor for macOS   "
echo "==========================================="

# Check swiftc compiler availability
if ! command -v swiftc >/dev/null 2>&1; then
    echo ""
    echo "❌ Xcode Command Line Tools (swiftc) is required."
    echo "👉 Please run this in Terminal: xcode-select --install"
    echo "Once installation completes, re-run this command."
    exit 1
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

# Stop existing instance if running
launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x netspeed 2>/dev/null || true

echo "⬇️  Downloading source files..."
curl -fsSL "$RAW_BASE/main.swift" -o "$INSTALL_DIR/main.swift"
curl -fsSL "$RAW_BASE/Uninstall.command" -o "$INSTALL_DIR/Uninstall.command" 2>/dev/null || true
chmod +x "$INSTALL_DIR/Uninstall.command" 2>/dev/null || true

echo "⚙️  Compiling native binary for this Mac..."
swiftc -O "$INSTALL_DIR/main.swift" -o "$INSTALL_DIR/netspeed"
chmod +x "$INSTALL_DIR/netspeed"

echo "🚀 Setting up auto-start LaunchAgent..."
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.netspeed</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/netspeed</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

# Start service
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || launchctl load "$PLIST_PATH" 2>/dev/null || "$INSTALL_DIR/netspeed" &

echo ""
echo "✅ Installation complete!"
echo "• NetSpeed speedometer is now active in your menu bar."
echo "• Starts automatically at login."
echo "• To uninstall at any time, run:"
echo "  curl -fsSL $RAW_BASE/uninstall.sh | bash"
