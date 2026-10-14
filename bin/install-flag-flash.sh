#!/bin/bash
# Build and install the language-flag flash and its settings app.
# Flashes the active Superwhisper language when the dictation key is pressed.
# See README.md#language-flag-flash.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT="$ROOT/bin/flag-flash.swift"
SETTINGS_SWIFT="$ROOT/bin/flag-settings.swift"
ICON="$ROOT/assets/language-flash-icon.png"
SUPPORT="${SWIFTBAR_SUPPORT_DIR:-$HOME/Library/Application Support/superwhisper-swiftbar}"
APP="$SUPPORT/bin/Superwhisper Language Flash.app"
BIN="$APP/Contents/MacOS/Superwhisper Language Flash"
LOG="$SUPPORT/flag-flash.log"
LABEL="com.burbank.superwhisper-flag-flash"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if [ -w /Applications ]; then
  SETTINGS_APP="/Applications/Language Flash.app"
else
  mkdir -p "$HOME/Applications"
  SETTINGS_APP="$HOME/Applications/Language Flash.app"
fi
SETTINGS_BIN="$SETTINGS_APP/Contents/MacOS/Language Flash"

render_icon() {
  local dest_app="$1"
  local work iconset pair size name
  work="$(mktemp -d)"
  iconset="$work/AppIcon.iconset"
  mkdir -p "$iconset" "$dest_app/Contents/Resources"
  local -a pairs=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
  )
  for pair in "${pairs[@]}"; do
    size="${pair%%:*}"
    name="${pair#*:}"
    sips -z "$size" "$size" "$ICON" --out "$iconset/$name" >/dev/null
  done
  iconutil -c icns "$iconset" -o "$dest_app/Contents/Resources/AppIcon.icns"
  rm -rf "$work"
}

write_info_plist() {
  local dest_app="$1"
  local executable="$2"
  local bundle_id="$3"
  local display_name="$4"
  local ui_element="$5"
  cat > "$dest_app/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${executable}</string>
  <key>CFBundleIdentifier</key>
  <string>${bundle_id}</string>
  <key>CFBundleName</key>
  <string>${display_name}</string>
  <key>CFBundleDisplayName</key>
  <string>${display_name}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.1</string>
  <key>LSUIElement</key>
  <${ui_element}/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
  printf 'APPL????' > "$dest_app/Contents/PkgInfo"
}

mkdir -p "$SUPPORT/bin" "$HOME/.local/bin" "$(dirname "$PLIST")"

echo "Compiling language flash…"
BUILD="$(mktemp -d)"
swiftc -O -o "$BUILD/agent" "$SWIFT"
swiftc -O -o "$BUILD/settings" "$SETTINGS_SWIFT"
chmod +x "$BUILD/agent" "$BUILD/settings"

DOMAIN="gui/$(id -u)"
SERVICE="${DOMAIN}/${LABEL}"
# Stop the running copy before replacing its binary.
launchctl bootout "$SERVICE" 2>/dev/null || true
osascript -e 'quit app "Language Flash"' >/dev/null 2>&1 || true

case "$APP" in
  */"Superwhisper Language Flash.app") ;;
  *) echo "Refusing to replace $APP"; exit 1 ;;
esac
case "$SETTINGS_APP" in
  */"Language Flash.app") ;;
  *) echo "Refusing to replace $SETTINGS_APP"; exit 1 ;;
esac
rm -rf "$APP" "$SETTINGS_APP"
mkdir -p "$APP/Contents/MacOS" "$SETTINGS_APP/Contents/MacOS"
mv "$BUILD/agent" "$BIN"
mv "$BUILD/settings" "$SETTINGS_BIN"
rm -rf "$BUILD"

write_info_plist "$APP" "Superwhisper Language Flash" "com.burbank.superwhisper-flag-flash" "Superwhisper Language Flash" "true"
write_info_plist "$SETTINGS_APP" "Language Flash" "com.burbank.language-flash" "Language Flash" "false"
render_icon "$APP"
render_icon "$SETTINGS_APP"

# One copy. The Applications folder is the one Finder and Launchpad show.
if [ "$SETTINGS_APP" = "/Applications/Language Flash.app" ]; then
  rm -rf "$HOME/Applications/Language Flash.app"
fi

ln -sfn "$BIN" "$HOME/.local/bin/flag-flash"

sed -e "s|__APP_EXECUTABLE__|${BIN}|g" \
    -e "s|__LOG_PATH__|${LOG}|g" \
    "$ROOT/LaunchAgents/com.burbank.superwhisper-flag-flash.plist.template" > "$PLIST"

# A disabled service makes bootstrap fail with "Bootstrap failed: 5: Input/output error".
launchctl enable "$SERVICE" 2>/dev/null || true
launchctl bootout "$SERVICE" 2>/dev/null || true
if ! launchctl bootstrap "$DOMAIN" "$PLIST"; then
  launchctl enable "$SERVICE" 2>/dev/null || true
  launchctl bootout "$SERVICE" 2>/dev/null || true
  launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null || true
fi
launchctl kickstart -k "$SERVICE" 2>/dev/null || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$SETTINGS_APP" >/dev/null 2>&1 || true
fi

echo "Settings app: $SETTINGS_APP"
echo "Open Language Flash from Applications. It has the flag icon."
echo "Background item: Superwhisper Language Flash"
echo "Leave that background item allowed under Privacy & Security → Accessibility."
echo "System Settings → General → Login Items & Extensions → Allow in the Background"
if launchctl print "$SERVICE" 2>/dev/null | grep -q "state = running"; then
  echo "Background flash: running"
else
  echo "Background flash: not running. Open Language Flash and click Start."
fi
echo "Log: $LOG"

open "$SETTINGS_APP" || true
