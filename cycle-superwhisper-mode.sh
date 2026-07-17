#!/bin/bash

# cycle-superwhisper-mode.sh
#
# Cycles to the next Superwhisper mode using the official deep link API.
# Designed to be triggered by BetterTouchTool (e.g. F3).
#
# Modes are discovered from ~/Documents/superwhisper/modes/*.json and
# ordered by filename so the cycle order stays stable as you add languages.
# Uses open -g so Superwhisper does not steal focus from the app you're in.

set -euo pipefail

PREF_DOMAIN="com.superduper.superwhisper"
MODES_DIR="$HOME/Documents/superwhisper/modes"

if [ ! -d "$MODES_DIR" ]; then
    echo "Modes directory not found: $MODES_DIR" >&2
    exit 1
fi

# Remember whatever app currently has focus (process name)
front_app=$(/usr/bin/osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)

# Build ordered list of mode keys (stable sort by filename)
keys=()
while IFS= read -r key; do
    [ -n "$key" ] && keys+=("$key")
done < <(/usr/bin/python3 - "$MODES_DIR" <<'PY'
import json, pathlib, sys
for path in sorted(pathlib.Path(sys.argv[1]).glob("*.json")):
    try:
        key = json.load(open(path)).get("key") or ""
    except Exception:
        continue
    if key:
        print(key)
PY
)

if [ ${#keys[@]} -eq 0 ]; then
    echo "No modes found in $MODES_DIR" >&2
    exit 1
fi

active_key=$(/usr/bin/defaults read "$PREF_DOMAIN" activeModeKey 2>/dev/null || true)

# Find index of current mode; default to last so next becomes first
next_index=0
for i in "${!keys[@]}"; do
    if [ "${keys[$i]}" = "$active_key" ]; then
        next_index=$(( (i + 1) % ${#keys[@]} ))
        break
    fi
done

next_key="${keys[$next_index]}"

# Switch via Superwhisper's official deep link without activating the app
/usr/bin/open -g "superwhisper://mode?key=${next_key}"

# Refresh SwiftBar in the background
/usr/bin/open -g "swiftbar://refreshplugin?name=superwhisper-mode" 2>/dev/null || true

# Restore focus if Superwhisper still stole it
if [ -n "${front_app:-}" ] && [ "$front_app" != "superwhisper" ]; then
    /usr/bin/osascript -e "tell application \"System Events\" to set frontmost of first process whose name is \"${front_app}\" to true" 2>/dev/null || true
fi
