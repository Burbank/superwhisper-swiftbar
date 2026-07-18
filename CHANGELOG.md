# Changelog

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
