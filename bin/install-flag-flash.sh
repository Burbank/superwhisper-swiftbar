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
OLD_APP="$SUPPORT/bin/Superwhisper Language Flash.app"
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

echo "Language Flash goes in the main Applications folder, not Utilities."
echo "Destination: $SETTINGS_APP"
case "$ROOT" in
  *"/Mobile Documents/"*|*"CloudDocs"*)
    echo "This project folder is in iCloud. git pull here can fail with: mmap failed: Operation canceled"
    echo "Install from a copy outside iCloud:"
    echo "  git clone --branch cursor/dictation-flag-flash-f3a2 --single-branch https://github.com/Burbank/superwhisper-swiftbar.git \"\$HOME/.local/src/superwhisper-swiftbar\""
    echo "  \"\$HOME/.local/src/superwhisper-swiftbar/bin/install-flag-flash.sh\""
    ;;
esac

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
  <string>1.2</string>
  <key>CFBundleVersion</key>
  <string>1.2</string>
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

# Same Developer ID and notary login as yourMark. Ad-hoc signing remains when that certificate is absent.
sign_and_notarize() {
  local app="$1"
  local agent="$app/Contents/MacOS/Language Flash Agent"
  local identity="${CODESIGN_IDENTITY:-}"
  xattr -cr "$app" >/dev/null 2>&1 || true
  if [ -z "$identity" ]; then
    identity="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/{print $2; exit}' || true)"
  fi
  if [ -z "$identity" ]; then
    echo "No Developer ID certificate on this Mac. Language Flash is signed locally, so Gatekeeper may ask before it opens."
    codesign --force --deep --sign - "$app" || echo "Could not sign Language Flash. Login Items may hide it."
    return 0
  fi
  echo "Signing with $identity"
  if ! codesign --force --options runtime --timestamp --sign "$identity" "$agent" \
    || ! codesign --force --options runtime --timestamp --sign "$identity" "$app"; then
    echo "Developer ID signing failed. Signing locally instead."
    codesign --force --deep --sign - "$app" || echo "Could not sign Language Flash. Login Items may hide it."
    return 0
  fi
  local profile="${NOTARY_PROFILE:-yourmark-notary}"
  local work zip notary
  work="$(mktemp -d)"
  zip="$work/Language-Flash.zip"
  ditto -c -k --keepParent "$app" "$zip"
  notary="missing"
  if xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1; then
    echo "Sending Language Flash to Apple for notarization. This can take a few minutes."
    notary="failed"
    if xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait; then
      notary="ok"
    fi
  elif [ -n "${APPLE_API_KEY:-}" ] && [ -n "${APPLE_API_KEY_ID:-}" ] && [ -n "${APPLE_API_ISSUER:-}" ]; then
    echo "Sending Language Flash to Apple for notarization. This can take a few minutes."
    notary="failed"
    if xcrun notarytool submit "$zip" --key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" --wait; then
      notary="ok"
    fi
  elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
    echo "Sending Language Flash to Apple for notarization. This can take a few minutes."
    notary="failed"
    if xcrun notarytool submit "$zip" \
      --apple-id "$APPLE_ID" \
      --team-id "${APPLE_TEAM_ID:-R4SB7G9A32}" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --wait; then
      notary="ok"
    fi
  else
    echo "Signed with Developer ID. Notarization needs the same notary login as yourMark (keychain profile $profile)."
  fi
  if [ "$notary" = "ok" ]; then
    if xcrun stapler staple "$app"; then
      echo "Notarized. Other Macs can open Language Flash without the unidentified-developer warning."
    else
      echo "Apple accepted the app, but the ticket was not stapled. It can still open when this Mac is online."
    fi
  elif [ "$notary" = "failed" ]; then
    echo "Apple did not notarize this copy. Language Flash is still installed."
  fi
  rm -rf "$work"
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

case "$OLD_APP" in
  */"Superwhisper Language Flash.app") ;;
  *) echo "Refusing to replace $OLD_APP"; exit 1 ;;
esac
case "$SETTINGS_APP" in
  */"Language Flash.app") ;;
  *) echo "Refusing to replace $SETTINGS_APP"; exit 1 ;;
esac
# One app. The old Application Support bundle was a second copy of the same agent.
rm -rf "$OLD_APP" "$SETTINGS_APP"
mkdir -p "$SETTINGS_APP/Contents/MacOS" "$SETTINGS_APP/Contents/Library/LaunchAgents"
cp "$BUILD/agent" "$SETTINGS_APP/Contents/MacOS/Language Flash Agent"
mv "$BUILD/settings" "$SETTINGS_BIN"
rm -rf "$BUILD"
chmod +x "$SETTINGS_BIN" "$SETTINGS_APP/Contents/MacOS/Language Flash Agent"

write_info_plist "$SETTINGS_APP" "Language Flash" "com.burbank.language-flash" "Language Flash" "false"
render_icon "$SETTINGS_APP"
sed -e "s|__LOG_PATH__|${LOG}|g" \
    "$ROOT/LaunchAgents/com.burbank.language-flash-embedded.plist.template" \
    > "$SETTINGS_APP/Contents/Library/LaunchAgents/${LABEL}.plist"

# One copy. The Applications folder is the one Finder and Launchpad show.
if [ "$SETTINGS_APP" = "/Applications/Language Flash.app" ]; then
  rm -rf "$HOME/Applications/Language Flash.app"
fi

ln -sfn "$SETTINGS_APP/Contents/MacOS/Language Flash Agent" "$HOME/.local/bin/flag-flash"

sign_and_notarize "$SETTINGS_APP"

AGENT="$SETTINGS_APP/Contents/MacOS/Language Flash Agent"
cat > "$PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>AssociatedBundleIdentifiers</key>
  <array>
    <string>com.burbank.language-flash</string>
  </array>
  <key>ProgramArguments</key>
  <array>
    <string>${AGENT}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>${LOG}</string>
  <key>StandardOutPath</key>
  <string>${LOG}</string>
  <key>BurbankManagedAgent</key>
  <true/>
</dict>
</plist>
PLIST

# A disabled service makes bootstrap fail with "Bootstrap failed: 5".
launchctl enable "$SERVICE" 2>/dev/null || true
launchctl bootout "$SERVICE" 2>/dev/null || true
if ! launchctl bootstrap "$DOMAIN" "$PLIST"; then
  launchctl enable "$SERVICE" 2>/dev/null || true
  launchctl bootout "$SERVICE" 2>/dev/null || true
  launchctl bootstrap "$DOMAIN" "$PLIST"
fi
launchctl kickstart -k "$SERVICE" || true
if launchctl print "$SERVICE" 2>/dev/null | grep -q "state = running"; then
  echo "Background flash: running"
else
  echo "Background flash: not running. Open Language Flash and click Start."
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$SETTINGS_APP" >/dev/null 2>&1 || true
fi

echo "Settings app: $SETTINGS_APP"
echo "In Language Flash, turn on “Start when you log in”."
echo "macOS then lists Language Flash under System Settings → General → Login Items & Extensions."
echo "It is not inside a Utilities folder."
echo "If the flag stops appearing on the dictation key, allow Language Flash under Privacy & Security → Accessibility."
echo "Log: $LOG"

open "$SETTINGS_APP" || true
