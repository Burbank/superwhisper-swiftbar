#!/bin/bash

# superwhisper-mode.2s.sh — SwiftBar plugin
# Reads mode configs from ~/Documents/superwhisper/modes/*.json
# Switches modes via switch-superwhisper-mode.sh (deep link + sound cue)

PREF_DOMAIN="com.superduper.superwhisper"
MODES_DIR="$HOME/Documents/superwhisper/modes"
# Use space-free symlink — SwiftBar bash= breaks on "Application Support"
SWITCH_SCRIPT="$HOME/.local/bin/switch-superwhisper-mode"

active_key=$(/usr/bin/defaults read "$PREF_DOMAIN" activeModeKey 2>/dev/null)

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

active_name=""
TMPFILE=$(/usr/bin/mktemp)
trap '/bin/rm -f "$TMPFILE"' EXIT

/usr/bin/python3 - "$MODES_DIR" <<'PY' > "$TMPFILE"
import json, pathlib, sys
modes_dir = pathlib.Path(sys.argv[1])
for path in sorted(modes_dir.glob("*.json")):
    try:
        m = json.load(open(path))
    except Exception:
        continue
    key = m.get("key") or ""
    name = m.get("name") or key
    lang = m.get("language") or ""
    if key:
        print(f"{key}|{name}|{lang}")
PY

while IFS='|' read -r key name lang; do
    [ -z "$key" ] && continue
    if [ "$key" = "$active_key" ]; then
        active_name="$name"
        break
    fi
done < "$TMPFILE"

[ -z "$active_name" ] && active_name="$active_key"

echo "$active_name"
echo "---"

while IFS='|' read -r key name lang; do
    [ -z "$key" ] && continue
    label="$name"
    [ -n "$lang" ] && label="$name  ($lang)"
    if [ "$key" = "$active_key" ]; then
        echo "● $label | color=white"
    else
        echo "○ $label | bash=\"$SWITCH_SCRIPT\" param1=$key terminal=false refresh=true"
    fi
done < "$TMPFILE"

echo "---"
echo "Open superwhisper | href=superwhisper://"
echo "Refresh | refresh=true"
