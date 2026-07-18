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

### 3. Keyboard toggle (F3) without breaking volume keys

macOS cannot make only F3 a standard function key. Use BetterTouchTool only (no Karabiner):

1. Turn **Use F1, F2, etc. keys as standard function keys** **on** so bare **F3** reaches BTT.
2. BTT global shortcut **F3** → Run Apple Script (async):

   ```applescript
   do shell script "/Users/YOUR_USERNAME/.local/bin/cycle-superwhisper-mode"
   ```

3. Because step 1 would otherwise break volume/brightness, also add BTT shortcuts that restore them:
   - **F1** → Brightness Down  
   - **F2** → Brightness Up  
   - **F10** → Mute  
   - **F11** → Volume Down  
   - **F12** → Volume Up  

`bin/ensure-btt-f3.sh` can recreate that set (optional; LaunchAgent left disabled by default).

**Keep BTT sync off.** Dropbox/iCloud sync can overwrite local shortcuts. For backups, export a `.bttpreset` or copy `~/Library/Application Support/BetterTouchTool`.

## Tip: flag emoji mode names

Rename modes in superwhisper to 🇺🇸 / 🇳🇱 / etc. for a compact menu bar indicator.

## Layout

```
~/Documents/swiftbar/                         # SwiftBar plugins ONLY
  superwhisper-mode.2s.sh
  001-ip-flag.2m.rb                           # optional other plugins
  btc.5m.sh

~/Library/Application Support/superwhisper-swiftbar/
  cycle-superwhisper-mode.sh
  switch-superwhisper-mode.sh
  ensure-btt-f3.sh
  sounds/
    now_US.wav
    now_NL.wav
    now_ES.wav
    play.fifo                                 # runtime
  bin/
    sound-server.swift
    Superwhisper Mode Sounds.app/

~/.local/bin/
  cycle-superwhisper-mode -> …/cycle-superwhisper-mode.sh
  switch-superwhisper-mode -> …/switch-superwhisper-mode.sh
```





## Important: keep the SwiftBar plugin folder clean

Only put actual SwiftBar plugins in your SwiftBar plugin directory (e.g. `~/Documents/swiftbar`).

Sounds, binaries, and helper scripts live in:

`~/Library/Application Support/superwhisper-swiftbar/`

If non-plugin files sit in the SwiftBar folder, they show up as broken `?` menu bar items.

Hotkeys and SwiftBar actions should call space-free symlinks in `~/.local/bin/` (`cycle-superwhisper-mode`, `switch-superwhisper-mode`), because paths under `Application Support` break AppleScript/`bash=` on the space.

## Persistence across reboots

Two LaunchAgents keep things working after restart:

1. **Superwhisper Mode Sounds** — preloads cue audio  
2. **ensure-superwhisper-f3** (optional, disabled by default) — can recreate the F3 shortcut at login; left off because an earlier hourly version spawned duplicates

They live under `~/Library/LaunchAgents/` and the ensure script under  
`~/Library/Application Support/superwhisper-swiftbar/` (LaunchAgents cannot reliably execute scripts from `Documents` due to macOS privacy).

Use standard function keys **on** plus BTT: F3 cycles modes; F11/F12 (etc.) restore volume/brightness. Leave BTT Dropbox/iCloud sync disabled.

## Related

- [superwhisper docs: Switching Modes](https://superwhisper.com/docs/modes/switching-modes)
- [Raycast extension](https://www.raycast.com/nchudleigh/superwhisper)
- [Alfred workflow](https://github.com/ognistik/alfred-superwhisper)

## License

MIT

### Symlinks for hotkeys / SwiftBar actions

Because `Application Support` contains a space, create space-free wrappers:

```bash
mkdir -p ~/.local/bin
SUPPORT="$HOME/Library/Application Support/superwhisper-swiftbar"
ln -sfn "$SUPPORT/cycle-superwhisper-mode.sh" ~/.local/bin/cycle-superwhisper-mode
ln -sfn "$SUPPORT/switch-superwhisper-mode.sh" ~/.local/bin/switch-superwhisper-mode
```

Point BetterTouchTool at:

```applescript
do shell script "/Users/YOUR_USERNAME/.local/bin/cycle-superwhisper-mode"
```
