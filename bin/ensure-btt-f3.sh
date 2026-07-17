#!/bin/bash

# ensure-btt-f3.sh
# Ensures the Superwhisper F3 BetterTouchTool shortcut exists and is enabled.
# Runs at login (LaunchAgent) and hourly as a safety net.

set -euo pipefail

CYCLE="/Users/DuniaMBP/Library/Application Support/superwhisper-swiftbar/cycle-superwhisper-mode.sh"
UUID_FILE="/Users/DuniaMBP/Library/Application Support/superwhisper-swiftbar/btt-f3-trigger-uuid"
NOTE="Cycle Superwhisper language modes"
ASCRIPT="do shell script \"${CYCLE}\""

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Wait for BetterTouchTool (up to ~90s after login)
for _ in $(seq 1 90); do
    if pgrep -x BetterTouchTool >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! pgrep -x BetterTouchTool >/dev/null 2>&1; then
    log "BetterTouchTool is not running"
    exit 1
fi

# Allow BTT to finish launching / cloud sync
sleep 5

/usr/bin/python3 - "$CYCLE" "$UUID_FILE" "$NOTE" "$ASCRIPT" <<'PY'
import json, subprocess, sys, uuid
from pathlib import Path

cycle, uuid_file, note, ascript = sys.argv[1:5]

def osa(*args, timeout=20):
    return subprocess.run(
        ["osascript", *args],
        capture_output=True, text=True, timeout=timeout,
    )

def get_trigger(uid):
    try:
        r = osa("-e", f'tell application "BetterTouchTool" to get_triggers trigger_uuid "{uid}"', timeout=15)
    except subprocess.TimeoutExpired:
        return None
    if r.returncode != 0 or not r.stdout.strip():
        return None
    try:
        data = json.loads(r.stdout)
    except json.JSONDecodeError:
        return None
    if isinstance(data, list) and data:
        return data[0]
    return None

def add_trigger(payload):
    r = osa(
        "-e",
        """
on run argv
  tell application "BetterTouchTool"
    return add_new_trigger (item 1 of argv)
  end tell
end run
""",
        json.dumps(payload),
        timeout=20,
    )
    return (r.stdout or "").strip()

def update_trigger(uid, payload):
    try:
        osa(
            "-e",
            """
on run argv
  tell application "BetterTouchTool"
    return update_trigger (item 1 of argv) json (item 2 of argv)
  end tell
end run
""",
            uid,
            json.dumps(payload),
            timeout=20,
        )
        return True
    except subprocess.TimeoutExpired:
        return False

payload = {
    "BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut",
    "BTTTriggerType": 0,
    "BTTEnabled": 1,
    "BTTEnabled2": 1,
    "BTTShortcutKeyCode": 99,
    "BTTShortcutModifierKeys": 8388608,
    "BTTShortcutAdvancedModifierKeys": "8388608",
    "BTTAdditionalConfiguration": "8388608",
    "BTTTriggerOnDown": 1,
    "BTTNotes": note,
    "BTTLayoutIndependentChar": note,
    "BTTPredefinedActionType": 172,
    "BTTPredefinedActionName": "Run Apple Script (async)",
    "BTTInlineAppleScript": ascript,
}

keep_uuid = None
saved = Path(uuid_file)
if saved.exists():
    candidate = saved.read_text().strip()
    if candidate:
        existing = get_trigger(candidate)
        if existing and "cycle-superwhisper-mode.sh" in (existing.get("BTTInlineAppleScript") or ""):
            keep_uuid = candidate
            print(f"found saved {keep_uuid}")

if keep_uuid is None:
    new_uuid = str(uuid.uuid4()).upper()
    payload_create = dict(payload)
    payload_create["BTTUUID"] = new_uuid
    created = add_trigger(payload_create)
    keep_uuid = created or new_uuid
    print(f"created {keep_uuid}")

if update_trigger(keep_uuid, payload):
    print(f"enabled {keep_uuid}")
else:
    print(f"warning: enable timed out for {keep_uuid}")

saved.parent.mkdir(parents=True, exist_ok=True)
saved.write_text(keep_uuid + "\n")
PY

/usr/bin/defaults write -g com.apple.keyboard.fnState -bool true
/bin/launchctl kickstart -k "gui/$(id -u)/com.burbank.superwhisper-mode-sounds" >/dev/null 2>&1 || true

log "ensure-btt-f3: done"
