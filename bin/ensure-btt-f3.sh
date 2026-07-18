#!/bin/bash

# ensure-btt-f3.sh
# Keeps ONE BTT F3 shortcut (keycode 99) for cycling Superwhisper modes.
# Also keeps BTT media remaps (F11/F12 volume, F1/F2 brightness, F10 mute)
# so those keys still work while macOS uses standard function keys
# (needed for bare F3). Deletes Superwhisper-related duplicates first.

set -euo pipefail

CYCLE="/Users/DuniaMBP/.local/bin/cycle-superwhisper-mode"
SUPPORT="/Users/DuniaMBP/Library/Application Support/superwhisper-swiftbar"
UUID_FILE="$SUPPORT/btt-f3-trigger-uuid"
MEDIA_UUID_FILE="$SUPPORT/btt-media-trigger-uuids.json"
LOCK_FILE="$SUPPORT/ensure-btt-f3.lock"
NOTE="Cycle Superwhisper language modes"
ASCRIPT="do shell script \"${CYCLE}\""

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

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

sleep 8

/usr/bin/python3 - "$CYCLE" "$UUID_FILE" "$MEDIA_UUID_FILE" "$NOTE" "$ASCRIPT" <<'PY'
import json, subprocess, sys, uuid
from pathlib import Path

cycle, uuid_file, media_uuid_file, note, ascript = sys.argv[1:6]

def osa(*args, timeout=45):
    return subprocess.run(["osascript", *args], capture_output=True, text=True, timeout=timeout)

def get_keyboard_triggers():
    try:
        r = osa("-e", 'tell application "BetterTouchTool" to get_triggers trigger_type "BTTTriggerTypeKeyboardShortcut"', timeout=45)
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
        'on run argv\ntell application "BetterTouchTool"\nreturn add_new_trigger (item 1 of argv)\nend tell\nend run',
        json.dumps(payload),
        timeout=20,
    )
    return (r.stdout or "").strip()

def update_trigger(uid, payload):
    try:
        osa(
            "-e",
            'on run argv\ntell application "BetterTouchTool"\nreturn update_trigger (item 1 of argv) json (item 2 of argv)\nend tell\nend run',
            uid,
            json.dumps(payload),
            timeout=20,
        )
        return True
    except subprocess.TimeoutExpired:
        return False

f3_payload = {
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
    "BTTPredefinedActionType": 195,
    "BTTPredefinedActionName": "Run Apple Script (async in background)",
    "BTTInlineAppleScript": ascript,
}

media_defs = [
    ("f1", 122, 29, "Brightness Down", "Superwhisper media: Brightness Down"),
    ("f2", 120, 28, "Brightness Up", "Superwhisper media: Brightness Up"),
    ("f10", 109, 22, "Mute", "Superwhisper media: Mute"),
    ("f11", 103, 25, "Volume Down", "Superwhisper media: Volume Down"),
    ("f12", 111, 24, "Volume Up", "Superwhisper media: Volume Up"),
]

triggers = get_keyboard_triggers()
if triggers is None:
    print("abort: could not list triggers; not creating")
    sys.exit(1)

matches = []
media_matches = {k: [] for k, *_ in media_defs}
for t in triggers:
    script = t.get("BTTInlineAppleScript") or ""
    notes = str(t.get("BTTNotes") or "") + str(t.get("BTTLayoutIndependentChar") or "")
    kc = t.get("BTTShortcutKeyCode")
    if "cycle-superwhisper-mode" in script or "Cycle Superwhisper" in notes or (kc in (99, 160) and "cycle-superwhisper" in script):
        matches.append(t)
    for key, mkc, *_rest in media_defs:
        if f"Superwhisper media:" in notes and kc == mkc:
            media_matches[key].append(t)

print(f"found {len(matches)} matching F3/cycle trigger(s)")

keep_uuid = None
saved = Path(uuid_file)
saved_uuid = saved.read_text().strip() if saved.exists() else ""
for t in matches:
    if t.get("BTTUUID") == saved_uuid:
        keep_uuid = saved_uuid
        break
if keep_uuid is None and matches:
    keep_uuid = sorted(matches, key=lambda t: t.get("BTTLastUpdatedAt") or 0, reverse=True)[0]["BTTUUID"]

for t in matches:
    uid = t["BTTUUID"]
    if keep_uuid and uid == keep_uuid:
        continue
    delete_trigger(uid)

if keep_uuid is None:
    new_uuid = str(uuid.uuid4()).upper()
    create_payload = dict(f3_payload)
    create_payload["BTTUUID"] = new_uuid
    created = add_trigger(create_payload)
    keep_uuid = created or new_uuid
    print(f"created {keep_uuid}")
else:
    print(f"keeping {keep_uuid}")

update_trigger(keep_uuid, f3_payload)
saved.parent.mkdir(parents=True, exist_ok=True)
saved.write_text(keep_uuid + "\n")

# Media remaps
saved_media = {}
if Path(media_uuid_file).exists():
    try:
        saved_media = json.loads(Path(media_uuid_file).read_text())
    except Exception:
        saved_media = {}

out_media = {}
for key, kc, action, action_name, mnote in media_defs:
    keep = None
    saved_uid = saved_media.get(key)
    for t in media_matches[key]:
        if t.get("BTTUUID") == saved_uid:
            keep = saved_uid
            break
    if keep is None and media_matches[key]:
        keep = sorted(media_matches[key], key=lambda t: t.get("BTTLastUpdatedAt") or 0, reverse=True)[0]["BTTUUID"]
    for t in media_matches[key]:
        if keep and t["BTTUUID"] == keep:
            continue
        delete_trigger(t["BTTUUID"])
    payload = {
        "BTTTriggerClass": "BTTTriggerTypeKeyboardShortcut",
        "BTTTriggerType": 0,
        "BTTEnabled": 1,
        "BTTEnabled2": 1,
        "BTTShortcutKeyCode": kc,
        "BTTShortcutModifierKeys": 8388608,
        "BTTShortcutAdvancedModifierKeys": "8388608",
        "BTTAdditionalConfiguration": "8388608",
        "BTTTriggerOnDown": 1,
        "BTTNotes": mnote,
        "BTTLayoutIndependentChar": mnote,
        "BTTPredefinedActionType": action,
        "BTTPredefinedActionName": action_name,
    }
    if keep is None:
        new_uuid = str(uuid.uuid4()).upper()
        payload["BTTUUID"] = new_uuid
        created = add_trigger(payload)
        keep = created or new_uuid
        print(f"created media {key} {keep}")
    else:
        update_trigger(keep, payload)
        print(f"keeping media {key} {keep}")
    out_media[key] = keep

Path(media_uuid_file).write_text(json.dumps(out_media, indent=2) + "\n")
print("ensure media+f3 done")
PY

# Bare F3 requires standard function keys; BTT remaps restore volume/brightness.
/usr/bin/defaults write -g com.apple.keyboard.fnState -bool true
/bin/launchctl kickstart -k "gui/$(id -u)/com.burbank.superwhisper-mode-sounds" >/dev/null 2>&1 || true

log "ensure-btt-f3: done"
