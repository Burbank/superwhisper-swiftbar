#!/bin/bash

# ensure-btt-f3.sh
# Ensures the Superwhisper F3 BetterTouchTool shortcut exists and is enabled.
# Intended to run at login after BTT starts (and anytime manually).

set -euo pipefail

CYCLE="/Users/DuniaMBP/Documents/swiftbar/cycle-superwhisper-mode.sh"
UUID_FILE="/Users/DuniaMBP/Library/Application Support/superwhisper-swiftbar/btt-f3-trigger-uuid"
NOTE="Cycle Superwhisper language modes"
ASCRIPT="do shell script \"${CYCLE}\""

# Wait for BetterTouchTool (up to ~90s after login)
for _ in $(seq 1 90); do
    if pgrep -x BetterTouchTool >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! pgrep -x BetterTouchTool >/dev/null 2>&1; then
    echo "ensure-btt-f3: BetterTouchTool is not running" >&2
    exit 1
fi

# Allow BTT to finish launching / cloud sync before we touch triggers
sleep 8

/usr/bin/python3 - "$CYCLE" "$UUID_FILE" "$NOTE" "$ASCRIPT" <<'PY'
import json, subprocess, sys, uuid

cycle, uuid_file, note, ascript = sys.argv[1:5]

def run_osa(*extra_args, timeout=30):
    return subprocess.run(
        ["osascript", *extra_args],
        capture_output=True, text=True, timeout=timeout,
    )

def get_keyboard_triggers():
    r = run_osa("-e", 'tell application "BetterTouchTool" to get_triggers trigger_type "BTTTriggerTypeKeyboardShortcut"')
    if r.returncode != 0 or not r.stdout.strip():
        return []
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return []

def add_trigger(payload):
    r = run_osa(
        "-e",
        """
on run argv
  tell application "BetterTouchTool"
    return add_new_trigger (item 1 of argv)
  end tell
end run
""",
        json.dumps(payload),
    )
    return (r.stdout or "").strip()

def update_trigger(uid, payload):
    run_osa(
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
    )

def delete_trigger(uid):
    run_osa("-e", f'tell application "BetterTouchTool" to delete_trigger "{uid}"')

payload_base = {
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

triggers = get_keyboard_triggers()
cycle_matches = [
    t for t in triggers
    if "cycle-superwhisper-mode.sh" in (t.get("BTTInlineAppleScript") or "")
]

keep = None
if cycle_matches:
    keep = sorted(cycle_matches, key=lambda t: t.get("BTTLastUpdatedAt") or 0, reverse=True)[0]
    for t in cycle_matches:
        if t["BTTUUID"] != keep["BTTUUID"]:
            delete_trigger(t["BTTUUID"])
            print(f"removed duplicate {t['BTTUUID']}")

if keep is None:
    new_uuid = str(uuid.uuid4()).upper()
    payload = dict(payload_base)
    payload["BTTUUID"] = new_uuid
    created = add_trigger(payload)
    keep_uuid = created or new_uuid
    print(f"created {keep_uuid}")
else:
    keep_uuid = keep["BTTUUID"]
    print(f"found {keep_uuid}")

update_trigger(keep_uuid, payload_base)
print(f"enabled {keep_uuid}")

with open(uuid_file, "w") as f:
    f.write(keep_uuid + "\n")
PY

# Bare F3 as a function key (not Mission Control / Show Desktop)
/usr/bin/defaults write -g com.apple.keyboard.fnState -bool true

# Keep the sound cue agent alive
/bin/launchctl kickstart -k "gui/$(id -u)/com.burbank.superwhisper-mode-sounds" >/dev/null 2>&1 || true

echo "ensure-btt-f3: done"
