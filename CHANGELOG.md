# Changelog

## 2026-10-12

- Flash a large Dutch, American, or Spanish flag for about a second when dictation starts
- A different key on the Mac keyboard and on an external keyboard both flash. Mode shortcuts and the start of a recording are watched, not only one global key
- The flag follows the active mode (`activeModeKey` and the mode’s language). See [Language flag flash](README.md#language-flag-flash)
- Background app **Superwhisper Language Flash** ([bin/flag-flash.swift](bin/flag-flash.swift)), listen-only, so the shortcut still reaches Superwhisper

## 2026-07-18 (media keys + F3)

- Fix broken Mission Control keycode-160 binding (physical F3 never matched)
- Restore working BTT **F3** (keycode 99) + `fnState` on for bare F3
- Bind full Apple media row in BTT (F1–F2, F4–F12); only F3 is custom
- Disable macOS Show Desktop on F11 (symbolic hotkeys 36/37) so Volume Down works
- Keep Karabiner out of this path (Apple keyboards ignored; no superwhisper rule)

## 2026-07-18 (BTT sync)

- Leave BetterTouchTool Dropbox and iCloud sync off to avoid cloud/local preset conflicts overwriting the F3 shortcut
- Prefer local BTT config + manual preset export over live cloud sync

## 2026-07-18 (hotfix)

- Remove 17 duplicate F3 triggers caused by hourly ensure agent
- Disable ensure LaunchAgent by default; keep a single working F3 shortcut

## 2026-07-18

- Stop ensure agent from creating duplicate F3 triggers every hour; dedupe on login only

## 2026-07-17 (persistence)

- Add login LaunchAgent `ensure-superwhisper-f3` to recreate/re-enable the BTT F3 shortcut after restarts

## 2026-07-17 (later)

- Add `sounds/now_ES.wav` for future Spanish modes (`es` language / related keys)

## 2026-07-17

- SwiftBar plugin reads modes from `~/Documents/superwhisper/modes/*.json`
- Mode switching via official `superwhisper://mode?key=` deep links
- Click-to-switch and F3 cycle keep the frontmost app focused (`open -g`)
- Instant audio cues via background **Superwhisper Mode Sounds** agent
  (preloaded `now_US.wav` / `now_NL.wav`, FIFO trigger)
- BetterTouchTool integration for cycling modes with a hotkey
- Install script builds the agent and registers its LaunchAgent
