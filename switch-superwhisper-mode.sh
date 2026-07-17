#!/bin/bash

# switch-superwhisper-mode.sh <mode-key>
# Instant cue via preloaded sound-server, then background mode switch.

MODE_KEY="${1:-}"
[ -n "$MODE_KEY" ] || { echo "Usage: $0 <mode-key>" >&2; exit 1; }

FIFO="$HOME/Documents/swiftbar/sounds/play.fifo"

# Fire the preloaded cue immediately (~1ms if sound-server is running)
if [ -p "$FIFO" ]; then
    printf '%s\n' "$MODE_KEY" > "$FIFO"
else
    case "$MODE_KEY" in
        default) /usr/bin/afplay "$HOME/Documents/swiftbar/sounds/now_US.wav" & ;;
        super)   /usr/bin/afplay "$HOME/Documents/swiftbar/sounds/now_NL.wav" & ;;
    esac
fi

front_app=$(/usr/bin/osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)

/usr/bin/open -g "superwhisper://mode?key=${MODE_KEY}"
/usr/bin/open -g "swiftbar://refreshplugin?name=superwhisper-mode" 2>/dev/null || true

if [ -n "${front_app:-}" ] && [ "$front_app" != "superwhisper" ]; then
    /usr/bin/osascript -e "tell application \"System Events\" to set frontmost of first process whose name is \"${front_app}\" to true" 2>/dev/null || true
fi
