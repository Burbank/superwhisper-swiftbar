#!/bin/bash

# superwhisper-mode.2s.sh — SwiftBar plugin
# Reads mode configs from ~/Documents/superwhisper/modes/*.json
# Switches modes via superwhisper://mode?key=MODE_KEY deep link
#
# https://superwhisper.com · https://swiftbar.app

PREF_DOMAIN="com.superduper.superwhisper"
MODES_DIR="$HOME/Documents/superwhisper/modes"

active_key=$(defaults read "$PREF_DOMAIN" activeModeKey 2>/dev/null)

if [ -z "$active_key" ]; then
    echo "SW?"
    echo "---"
    echo "Could not read superwhisper preferences"
    exit 0
fi

if [ ! -d "$MODES_DIR" ]; then
    echo "SW?"
    echo "---"
    echo "Modes directory not found"
    echo "Expected: $MODES_DIR"
    exit 0
fi

# Parse all mode JSON files
active_name=""
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

for f in "$MODES_DIR"/*.json; do
    [ -f "$f" ] || continue
    python3 -c "
import json, sys
m = json.load(open(sys.argv[1]))
print(m['key'] + '|' + m['name'] + '|' + m.get('language', ''))
" "$f" 2>/dev/null >> "$TMPFILE"
done

# Find the active mode name for the menu bar
while IFS='|' read -r key name lang; do
    [ -z "$key" ] && continue
    if [ "$key" = "$active_key" ]; then
        active_name="$name"
        break
    fi
done < "$TMPFILE"

[ -z "$active_name" ] && active_name="$active_key"

# Menu bar: mode name only
echo "$active_name"

# Dropdown
echo "---"

while IFS='|' read -r key name lang; do
    [ -z "$key" ] && continue
    label="$name"
    [ -n "$lang" ] && label="$name  ($lang)"
    if [ "$key" = "$active_key" ]; then
        echo "● $label | color=white"
    else
        echo "○ $label | href=superwhisper://mode?key=$key"
    fi
done < "$TMPFILE"

echo "---"
echo "Open superwhisper | href=superwhisper://"
echo "Refresh | refresh=true"
