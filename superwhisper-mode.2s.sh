#!/bin/bash

# superwhisper-mode.2s.sh
#
# SwiftBar plugin that displays the active superwhisper mode in the macOS menu bar.
# https://superwhisper.com · https://swiftbar.app
#
# superwhisper stores an internal mode key (e.g. "default") in its preferences,
# but not the display name you set in the UI. This plugin builds a mapping from
# internal keys to display names by observing the recording history: each time a
# new recording appears, the active key is associated with that recording's mode
# name. After one dictation per mode the mapping is complete and persists across
# restarts.

PREF_DOMAIN="com.superduper.superwhisper"
DB_PATH="$HOME/Library/Application Support/superwhisper/database/superwhisper.sqlite"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/superwhisper-swiftbar"
MAP_FILE="$CACHE_DIR/mode-map.txt"
LAST_TS_FILE="$CACHE_DIR/last-recording-ts.txt"

mkdir -p "$CACHE_DIR"
touch "$MAP_FILE" "$LAST_TS_FILE"

active_key=$(defaults read "$PREF_DOMAIN" activeModeKey 2>/dev/null)

if [ -z "$active_key" ]; then
    echo "SW?"
    echo "---"
    echo "Could not read superwhisper preferences"
    echo "Is superwhisper installed? | href=https://superwhisper.com"
    exit 0
fi

# When a new recording appears, map the current active key to its mode name.
# This is the only reliable bridge between internal keys and display names.
if [ -f "$DB_PATH" ]; then
    latest_row=$(sqlite3 "$DB_PATH" \
        "SELECT datetime, modeName, modelName, languageModelName
         FROM recording ORDER BY datetime DESC LIMIT 1;" 2>/dev/null)
fi

if [ -n "$latest_row" ]; then
    latest_ts=$(echo "$latest_row" | cut -d'|' -f1)
    latest_mode_name=$(echo "$latest_row" | cut -d'|' -f2)
    latest_whisper=$(echo "$latest_row" | cut -d'|' -f3)
    latest_lang=$(echo "$latest_row" | cut -d'|' -f4)

    prev_ts=$(cat "$LAST_TS_FILE" 2>/dev/null)
    if [ "$latest_ts" != "$prev_ts" ]; then
        echo "$latest_ts" > "$LAST_TS_FILE"
        grep -v "^${active_key}=" "$MAP_FILE" > "$MAP_FILE.tmp" 2>/dev/null || true
        echo "${active_key}=${latest_mode_name}|${latest_whisper}|${latest_lang}" >> "$MAP_FILE.tmp"
        mv "$MAP_FILE.tmp" "$MAP_FILE"
    fi
fi

# Look up the display name for the active key
display_name=""
whisper_model=""
lang_model=""

cached=$(grep "^${active_key}=" "$MAP_FILE" 2>/dev/null | tail -1 | cut -d'=' -f2-)
if [ -n "$cached" ]; then
    display_name=$(echo "$cached" | cut -d'|' -f1)
    whisper_model=$(echo "$cached" | cut -d'|' -f2)
    lang_model=$(echo "$cached" | cut -d'|' -f3)
fi

[ -z "$display_name" ] && display_name="$active_key"

# --- Menu bar: display name only (e.g. a flag emoji) ---
echo "$display_name"

# --- Dropdown menu ---
echo "---"
echo "Mode: $display_name | color=white"
if [ -n "$whisper_model" ] && [ "$whisper_model" != "" ]; then
    echo "Whisper: $whisper_model | color=#8BE9FD"
fi
if [ -n "$lang_model" ] && [ "$lang_model" != "" ]; then
    echo "LLM: $lang_model | color=#50FA7B"
fi
echo "---"

while IFS='=' read -r key rest; do
    [ -z "$key" ] && continue
    name=$(echo "$rest" | cut -d'|' -f1)
    if [ "$key" = "$active_key" ]; then
        echo "● $name | color=white"
    else
        echo "○ $name | color=gray"
    fi
done < "$MAP_FILE"

echo "---"
echo "Open superwhisper | href=superwhisper://"
echo "Refresh | refresh=true"
