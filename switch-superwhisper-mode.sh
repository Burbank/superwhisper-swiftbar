#!/bin/bash

# switch-superwhisper-mode.sh <mode-key>
# Instant cue via preloaded sound-server, then background mode switch.

MODE_KEY="${1:-}"
[ -n "$MODE_KEY" ] || { echo "Usage: $0 <mode-key>" >&2; exit 1; }

SOUNDS_DIR="$HOME/Documents/swiftbar/sounds"
FIFO="$SOUNDS_DIR/play.fifo"
MODES_DIR="$HOME/Documents/superwhisper/modes"

# Resolve a sound token: known mode keys first, else mode language (en/nl/es/…)
sound_token="$MODE_KEY"
case "$MODE_KEY" in
    default|super) ;;
    *)
        lang=$(/usr/bin/python3 - "$MODES_DIR" "$MODE_KEY" <<'PY' 2>/dev/null
import json, pathlib, sys
modes_dir, want = pathlib.Path(sys.argv[1]), sys.argv[2]
for path in modes_dir.glob("*.json"):
    try:
        m = json.load(open(path))
    except Exception:
        continue
    if m.get("key") == want:
        print((m.get("language") or "").split("-")[0].lower())
        break
PY
)
        [ -n "$lang" ] && sound_token="$lang"
        ;;
esac

# Fire the preloaded cue immediately (~1ms if sound-server is running)
if [ -p "$FIFO" ]; then
    printf '%s\n' "$sound_token" > "$FIFO"
else
    case "$sound_token" in
        default|en|US|us) /usr/bin/afplay "$SOUNDS_DIR/now_US.wav" & ;;
        super|nl|NL)      /usr/bin/afplay "$SOUNDS_DIR/now_NL.wav" & ;;
        es|ES|spanish)    /usr/bin/afplay "$SOUNDS_DIR/now_ES.wav" & ;;
    esac
fi

front_app=$(/usr/bin/osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)

/usr/bin/open -g "superwhisper://mode?key=${MODE_KEY}"
/usr/bin/open -g "swiftbar://refreshplugin?name=superwhisper-mode" 2>/dev/null || true

if [ -n "${front_app:-}" ] && [ "$front_app" != "superwhisper" ]; then
    /usr/bin/osascript -e "tell application \"System Events\" to set frontmost of first process whose name is \"${front_app}\" to true" 2>/dev/null || true
fi
