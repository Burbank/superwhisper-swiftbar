# Changelog

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
