#!/bin/bash
# Build and install "Superwhisper Mode Sounds" background agent.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT="$ROOT/bin/sound-server.swift"
PLUGIN_DIR="${SWIFTBAR_PLUGIN_DIR:-$HOME/Documents/swiftbar}"
APP="$PLUGIN_DIR/bin/Superwhisper Mode Sounds.app"
BIN="$APP/Contents/MacOS/Superwhisper Mode Sounds"
SOUNDS_DIR="$PLUGIN_DIR/sounds"
LOG="$SOUNDS_DIR/sound-server.log"
LABEL="com.burbank.superwhisper-mode-sounds"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

mkdir -p "$PLUGIN_DIR/bin" "$SOUNDS_DIR" "$APP/Contents/MacOS"

# Ensure cue sounds exist
for f in now_US.wav now_NL.wav; do
  if [ ! -f "$SOUNDS_DIR/$f" ] && [ -f "$ROOT/sounds/$f" ]; then
    cp "$ROOT/sounds/$f" "$SOUNDS_DIR/$f"
  fi
done

echo "Compiling sound server…"
swiftc -O -o "$BIN" "$SWIFT"
chmod +x "$BIN"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Superwhisper Mode Sounds</string>
  <key>CFBundleIdentifier</key>
  <string>com.burbank.superwhisper-mode-sounds</string>
  <key>CFBundleName</key>
  <string>Superwhisper Mode Sounds</string>
  <key>CFBundleDisplayName</key>
  <string>Superwhisper Mode Sounds</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

# Point the compiled binary at the user's sounds dir via the expected path
# (sound-server.swift reads ~/Documents/swiftbar/sounds)

sed -e "s|__APP_EXECUTABLE__|${BIN}|g" \
    -e "s|__LOG_PATH__|${LOG}|g" \
    "$ROOT/LaunchAgents/com.burbank.superwhisper-mode-sounds.plist.template" > "$PLIST"

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null || true

echo "Installed. Background item name: Superwhisper Mode Sounds"
echo "System Settings → General → Login Items & Extensions → Allow in the Background"
