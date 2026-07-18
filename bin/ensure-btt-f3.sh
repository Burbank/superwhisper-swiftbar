#!/bin/bash

# ensure-btt-f3.sh
# Legacy helper. Preferred setup: Karabiner maps Mission Control (physical F3 in
# media-key mode) to cycle-superwhisper-mode, with macOS fnState=false so volume
# keys stay normal. This script only dedupes/disables the old BTT F3 shortcut.

set -euo pipefail

CYCLE="/Users/DuniaMBP/.local/bin/cycle-superwhisper-mode"
UUID_FILE="/Users/DuniaMBP/Library/Application Support/superwhisper-swiftbar/btt-f3-trigger-uuid"
LOCK_FILE="/Users/DuniaMBP/Library/Application Support/superwhisper-swiftbar/ensure-btt-f3.lock"
NOTE="Cycle Superwhisper language modes"
ASCRIPT="do shell script \"${CYCLE}\""

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Prevent overlapping runs (clear stale locks older than 2 minutes)
if [ -d "$LOCK_FILE" ]; then
    lock_age=$(( $(/bin/date +%s) - $(/usr/bin/stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -gt 120 ]; then
        log "removing stale lock (${lock_age}s)"
        /bin/rm -rf "$LOCK_FILE"
    fi
fi
if ! /usr/bin/mkdir "$LOCK_FILE" 2>/dev/null; then
    log "another ensure run is in progress; exiting"
    exit 0
fi
trap '/bin/rm -rf "$LOCK_FILE" 2>/dev/null || true' EXIT

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

# Let BTT finish launching / syncing
sleep 8

/usr/bin/python3 - "$CYCLE" "$UUID_FILE" "$NOTE" "$ASCRIPT" <<'PY'
import json, subprocess, sys, uuid
from pathlib import Path

cycle, uuid_file, note, ascript = sys.argv[1:5]

def osa(*args, timeout=45):
    return subprocess.run(
        ["osascript", *args],
        capture_output=True, text=True, timeout=timeout,
    )

def get_keyboard_triggers():
    try:
        r = osa(
            "-e",
            'tell application "BetterTouchTool" to get_triggers trigger_type "BTTTriggerTypeKeyboardShortcut"',
            timeout=45,
        )
    except subprocess.TimeoutExpired:
        print("warning: listing triggers timed out")
        return None
    if r.returncode != 0 or not r.stdout.strip():
        print("warning: listing triggers failed:", (r.stderr or "")[:200])
        return None
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return None

def delete_trigger(uid):
    try:
        osa("-e", f'tell application "BetterTouchTool" to delete_trigger "{uid}"', timeout=15)
        print(f"deleted {uid}")
    except subprocess.TimeoutExpired:
        print(f"warning: delete timed out for {uid}")

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
    "BTTEnabled": 0,
    "BTTEnabled2": 0,
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
if triggers is None:
    # Do NOT create anything if we cannot list — avoids duplicate storms
    print("abort: could not list triggers; not creating")
    sys.exit(1)

matches = []
for t in triggers:
    script = t.get("BTTInlineAppleScript") or ""
    notes = str(t.get("BTTNotes") or "") + str(t.get("BTTLayoutIndependentChar") or "")
    kc = t.get("BTTShortcutKeyCode")
    if (
        "cycle-superwhisper-mode" in script
        or "Cycle Superwhisper" in notes
        or (kc == 99 and "cycle-superwhisper" in script)
    ):
        matches.append(t)

print(f"found {len(matches)} matching F3/cycle trigger(s)")

keep_uuid = None
saved = Path(uuid_file)
saved_uuid = saved.read_text().strip() if saved.exists() else ""

# Prefer saved UUID if it still exists among matches
for t in matches:
    if t.get("BTTUUID") == saved_uuid:
        keep_uuid = saved_uuid
        break

# Else keep the newest match
if keep_uuid is None and matches:
    keep_uuid = sorted(matches, key=lambda t: t.get("BTTLastUpdatedAt") or 0, reverse=True)[0]["BTTUUID"]

# Delete every match except the one we keep
for t in matches:
    uid = t["BTTUUID"]
    if keep_uuid and uid == keep_uuid:
        continue
    delete_trigger(uid)

if keep_uuid is None:
    new_uuid = str(uuid.uuid4()).upper()
    create_payload = dict(payload)
    create_payload["BTTUUID"] = new_uuid
    created = add_trigger(create_payload)
    keep_uuid = created or new_uuid
    print(f"created {keep_uuid}")
else:
    print(f"keeping {keep_uuid}")

if update_trigger(keep_uuid, payload):
    print(f"enabled {keep_uuid}")
else:
    print(f"warning: enable timed out for {keep_uuid}")

saved.parent.mkdir(parents=True, exist_ok=True)
saved.write_text(keep_uuid + "\n")
PY

# Keep media keys (volume etc.). Mission Control / F3 is handled by Karabiner.
/usr/bin/defaults write -g com.apple.keyboard.fnState -bool false
/bin/launchctl kickstart -k "gui/$(id -u)/com.burbank.superwhisper-mode-sounds" >/dev/null 2>&1 || true

log "ensure-btt-f3: done"
