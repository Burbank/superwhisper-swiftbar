#!/bin/bash
# Build and install "Superwhisper Language Flash".
# Flashes the active Superwhisper language when the dictation key is pressed.
# See README.md#language-flag-flash.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT="$ROOT/bin/flag-flash.swift"
SUPPORT="${SWIFTBAR_SUPPORT_DIR:-$HOME/Library/Application Support/superwhisper-swiftbar}"
APP="$SUPPORT/bin/Superwhisper Language Flash.app"
BIN="$APP/Contents/MacOS/Superwhisper Language Flash"
LOG="$SUPPORT/flag-flash.log"
LABEL="com.burbank.superwhisper-flag-flash"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

mkdir -p "$SUPPORT/bin" "$APP/Contents/MacOS" "$HOME/.local/bin"

echo "Compiling language flash…"
swiftc -O -o "$BIN" "$SWIFT"
chmod +x "$BIN"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Superwhisper Language Flash</string>
  <key>CFBundleIdentifier</key>
  <string>com.burbank.superwhisper-flag-flash</string>
  <key>CFBundleName</key>
  <string>Superwhisper Language Flash</string>
  <key>CFBundleDisplayName</key>
  <string>Superwhisper Language Flash</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

ln -sfn "$BIN" "$HOME/.local/bin/flag-flash"

sed -e "s|__APP_EXECUTABLE__|${BIN}|g" \
    -e "s|__LOG_PATH__|${LOG}|g" \
    "$ROOT/LaunchAgents/com.burbank.superwhisper-flag-flash.plist.template" > "$PLIST"

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null || true

echo "Installed. Background item name: Superwhisper Language Flash"
echo "System Settings → Privacy & Security → Accessibility → allow Superwhisper Language Flash"
echo "System Settings → General → Login Items & Extensions → Allow in the Background"
echo "Preview: ~/.local/bin/flag-flash --preview en"
echo "Log: $LOG"
