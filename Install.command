#!/bin/bash
set -e

# Resolve current directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
INSTALL_DIR="$HOME/.netspeed"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.netspeed.plist"

echo "==========================================="
echo "   Installing Menu Bar NetSpeed Monitor    "
echo "==========================================="

mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

# Stop any currently running instance
launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x netspeed 2>/dev/null || true

# Compile natively if swiftc is available, else use precompiled binary
if command -v swiftc >/dev/null 2>&1; then
    echo "Compiling NetSpeed natively for this Mac..."
    swiftc -O "$DIR/main.swift" -o "$INSTALL_DIR/netspeed"
elif [ -f "$DIR/netspeed" ]; then
    echo "Using bundled binary..."
    cp "$DIR/netspeed" "$INSTALL_DIR/netspeed"
else
    echo "❌ Error: swiftc compiler not found."
    echo "Please install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi

chmod +x "$INSTALL_DIR/netspeed"
cp "$DIR/main.swift" "$INSTALL_DIR/main.swift" 2>/dev/null || true
if [ -f "$DIR/Uninstall.command" ]; then
    cp "$DIR/Uninstall.command" "$INSTALL_DIR/Uninstall.command" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/Uninstall.command" 2>/dev/null || true
fi

# Create LaunchAgent plist for auto-start at login
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

# Load and launch immediately
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || launchctl load "$PLIST_PATH" 2>/dev/null || "$INSTALL_DIR/netspeed" &

echo ""
echo "✅ Installation complete!"
echo "• NetSpeed is now live in your menu bar."
echo "• It will start automatically every time you log in."
echo ""
echo "You can close this window."
exit 0
