# Changelog

## 2026-07-17 (path fix)

- Use `~/.local/bin` symlinks so F3/SwiftBar switching works with Application Support paths

## 2026-07-17 (plugin folder cleanup)

- Move sounds/helpers to Application Support so SwiftBar only loads real plugins

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
