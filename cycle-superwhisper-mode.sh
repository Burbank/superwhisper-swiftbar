#!/bin/bash

# cycle-superwhisper-mode.sh — next Superwhisper mode (BetterTouchTool / F3)

MODES_DIR="$HOME/Documents/superwhisper/modes"
SWITCH="$HOME/Library/Application Support/superwhisper-swiftbar/switch-superwhisper-mode.sh"
PREF_DOMAIN="com.superduper.superwhisper"

[ -x "$SWITCH" ] || exit 1
[ -d "$MODES_DIR" ] || exit 1

keys=()
while IFS= read -r f; do
    keys+=("$(/usr/bin/basename "$f" .json)")
done < <(/bin/ls -1 "$MODES_DIR"/*.json 2>/dev/null | /usr/bin/sort)

[ ${#keys[@]} -gt 0 ] || exit 1

active_key=$(/usr/bin/defaults read "$PREF_DOMAIN" activeModeKey 2>/dev/null || true)

next_index=0
for i in "${!keys[@]}"; do
    if [ "${keys[$i]}" = "$active_key" ]; then
        next_index=$(( (i + 1) % ${#keys[@]} ))
        break
    fi
done

exec "$SWITCH" "${keys[$next_index]}"
