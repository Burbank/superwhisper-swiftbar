# superwhisper-swiftbar

A [SwiftBar](https://swiftbar.app) plugin that shows your active [superwhisper](https://superwhisper.com) mode in the macOS menu bar, lets you switch modes with a click or keyboard shortcut, and plays an instant audio cue so you can tell which language mode is active without looking.

## Features

- Menu bar shows the active mode name (flag emoji, text, etc.)
- Click any inactive mode in the dropdown to switch
- Optional F3 (or any key) cycle via BetterTouchTool
- Official `superwhisper://mode?key=` deep links for real mode switching
- Reads modes from `~/Documents/superwhisper/modes/*.json` — always in sync
- Keeps your current app focused (`open -g`)
- Instant language cues via a background **Superwhisper Mode Sounds** agent (preloaded WAVs)

## How it works

| Piece | Role |
| --- | --- |
| `superwhisper-mode.2s.sh` | SwiftBar plugin — display + click-to-switch |
| `switch-superwhisper-mode.sh` | Plays cue + switches mode without stealing focus |
| `cycle-superwhisper-mode.sh` | Advances to the next mode (for BTT / hotkeys) |
| `bin/sound-server.swift` | Preloads `now_US.wav` / `now_NL.wav`, plays on FIFO command |
| LaunchAgent | Keeps **Superwhisper Mode Sounds** running in the background |

Cue mapping (mode key → sound):

| Mode key / language | Sound |
| --- | --- |
| `default` / `en` (English / 🇺🇸) | `sounds/now_US.wav` |
| `super` / `nl` (Dutch / 🇳🇱) | `sounds/now_NL.wav` |
| `es` (Spanish / 🇪🇸, when you add that mode) | `sounds/now_ES.wav` |

## Requirements

- macOS 13.3+
- [superwhisper](https://superwhisper.com) (v2.10+)
- [SwiftBar](https://swiftbar.app)
- Xcode Command Line Tools / `swiftc` (only to build the sound agent)
- `python3` (ships with macOS)

## Installation

### 1. SwiftBar plugin

```bash
PLUGIN_DIR="${HOME}/Documents/swiftbar"
mkdir -p "$PLUGIN_DIR"
# Point SwiftBar at this folder in its preferences if needed

curl -fsSL https://raw.githubusercontent.com/Burbank/superwhisper-swiftbar/main/superwhisper-mode.2s.sh \
  -o "$PLUGIN_DIR/superwhisper-mode.2s.sh"
curl -fsSL https://raw.githubusercontent.com/Burbank/superwhisper-swiftbar/main/switch-superwhisper-mode.sh \
  -o "$PLUGIN_DIR/switch-superwhisper-mode.sh"
curl -fsSL https://raw.githubusercontent.com/Burbank/superwhisper-swiftbar/main/cycle-superwhisper-mode.sh \
  -o "$PLUGIN_DIR/cycle-superwhisper-mode.sh"
chmod +x "$PLUGIN_DIR"/*.sh

# Hide helper scripts from the menu bar
defaults write com.ameba.SwiftBar DisabledPlugins -array \
  "cycle-superwhisper-mode.sh" \
  "switch-superwhisper-mode.sh"
```

Or clone the repo and copy the scripts into your SwiftBar plugin directory.

### 2. Sound cues + background agent

```bash
git clone https://github.com/Burbank/superwhisper-swiftbar.git
cd superwhisper-swiftbar
./bin/install-sound-server.sh
```

This compiles the agent, installs sounds into `~/Documents/swiftbar/sounds/`, and registers a LaunchAgent. In **System Settings → General → Login Items & Extensions → Allow in the Background** it appears as **Superwhisper Mode Sounds**.

Replace `sounds/now_US.wav` and `sounds/now_NL.wav` with your own cues if you like, then re-run the install script (or restart the agent).

### 3. BetterTouchTool (optional keyboard toggle)

1. Add a global keyboard shortcut (e.g. **F3**).
2. If F3 already triggers **Show Desktop**, edit that trigger instead of adding a second one.
3. Action → **Run Apple Script (async)**:

   ```applescript
   do shell script "/Users/YOUR_USERNAME/Documents/swiftbar/cycle-superwhisper-mode.sh"
   ```

4. For F3 without holding Fn: enable **Use F1, F2, etc. keys as standard function keys** in System Settings, or remap function keys in BTT.

## Tip: flag emoji mode names

Rename modes in superwhisper to 🇺🇸 / 🇳🇱 / etc. for a compact menu bar indicator.

## Layout

```
~/Documents/swiftbar/
  superwhisper-mode.2s.sh
  switch-superwhisper-mode.sh
  cycle-superwhisper-mode.sh
  sounds/
    now_US.wav
    now_NL.wav
    play.fifo          # created at runtime by the sound agent
  bin/
    Superwhisper Mode Sounds.app/
```

## Related

- [superwhisper docs: Switching Modes](https://superwhisper.com/docs/modes/switching-modes)
- [Raycast extension](https://www.raycast.com/nchudleigh/superwhisper)
- [Alfred workflow](https://github.com/ognistik/alfred-superwhisper)

## License

MIT
