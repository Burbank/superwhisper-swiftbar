#!/bin/bash

# cycle-superwhisper-mode.sh
#
# Cycles to the next Superwhisper mode using the official deep link API.
# Designed to be triggered by BetterTouchTool (e.g. F3).
#
# Modes are discovered from ~/Documents/superwhisper/modes/*.json and
# ordered by filename so the cycle order stays stable as you add languages.

set -euo pipefail

PREF_DOMAIN="com.superduper.superwhisper"
MODES_DIR="$HOME/Documents/superwhisper/modes"

if [ ! -d "$MODES_DIR" ]; then
    echo "Modes directory not found: $MODES_DIR" >&2
    exit 1
fi

# Build ordered list of mode keys (stable sort by filename)
keys=()
while IFS= read -r f; do
    key=$(/usr/bin/python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['key'])" "$f" 2>/dev/null) || continue
    [ -n "$key" ] && keys+=("$key")
done < <(/bin/ls -1 "$MODES_DIR"/*.json 2>/dev/null | /usr/bin/sort)

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

# Switch via Superwhisper's official deep link
/usr/bin/open "superwhisper://mode?key=${next_key}"

# Refresh SwiftBar so the menu bar flag updates immediately
/usr/bin/open "swiftbar://refreshplugin?name=superwhisper-mode" 2>/dev/null || true
