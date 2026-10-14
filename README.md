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
- [Language flag flash](#language-flag-flash) when the dictation key is pressed — source: [bin/flag-flash.swift](bin/flag-flash.swift)

## How it works

| Piece | Role |
| --- | --- |
| `superwhisper-mode.2s.sh` | SwiftBar plugin — display + click-to-switch |
| `switch-superwhisper-mode.sh` | Plays cue + switches mode without stealing focus |
| `cycle-superwhisper-mode.sh` | Advances to the next mode (for BTT / hotkeys) |
| `bin/sound-server.swift` | Preloads `now_US.wav` / `now_NL.wav`, plays on FIFO command |
| [`bin/flag-flash.swift`](bin/flag-flash.swift) | [Language flag flash](#language-flag-flash) on the dictation key |
| [`bin/flag-settings.swift`](bin/flag-settings.swift) | **Language Flash** settings window in Applications |
| LaunchAgent | Keeps **Superwhisper Mode Sounds** and **Superwhisper Language Flash** running in the background |

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
- Xcode Command Line Tools / `swiftc` (to build the sound agent and the flag flash)
- `python3` (ships with macOS)
- Accessibility permission for **Superwhisper Language Flash** (flag flash only)

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

### 3. Language flag flash

Source: [bin/flag-flash.swift](bin/flag-flash.swift). Settings window: [bin/flag-settings.swift](bin/flag-settings.swift). Installer: [bin/install-flag-flash.sh](bin/install-flag-flash.sh).

When the Superwhisper dictation key is pressed, a flag for the **current** mode flashes on every display for about 0.3 seconds. It is about a tenth of the screen wide and half transparent. Superwhisper still receives the key. The app does not track whether a recording is already running, so the press that stops a toggle flashes too. Holding the key does not flash again.

The Mac keyboard and an external keyboard can use different dictation keys. The app watches every record shortcut saved in Superwhisper, including a shortcut stored on a mode, and also the moment a recording starts. Either key shows the language that is active for that press.

The flag uses the same active mode as the menu bar:

| Mode key / language | Flag |
| --- | --- |
| `default` / `en` | United States |
| `super` / `nl` | Netherlands |
| `es` | Spain |
| anything else | the mode name, in large type |

Keep this git folder outside iCloud. A pull inside `Mobile Documents` can stop with `mmap failed: Operation canceled`, and then the installer never runs. On this Mac, use a local copy:

```bash
mkdir -p "$HOME/.local/src"
git clone --branch cursor/dictation-flag-flash-f3a2 --single-branch https://github.com/Burbank/superwhisper-swiftbar.git "$HOME/.local/src/superwhisper-swiftbar"
"$HOME/.local/src/superwhisper-swiftbar/bin/install-flag-flash.sh"
```

From a copy that is already on disk:

```bash
./bin/install-flag-flash.sh
```

The installer puts **Language Flash** in the main Applications folder, `/Applications`, next to your other apps. It does not go in Utilities. If that folder is not writable, it uses `~/Applications` instead, and the script prints the path. The icon is a Dutch flag with a small American flag on the corner.

The window has a **Start when you log in** checkbox. Turning it on registers Language Flash with macOS, so the name appears under **System Settings → General → Login Items & Extensions**. **Login Items…** opens that list. A background job installed by hand only produces a short notification and does not show the app name there.

Size, opacity, and time save as you move the sliders. The next dictation uses them. The background flash reads the file each time, so it does not need a restart after a change. **Preview Dutch**, **Preview English**, and **Preview Spanish** flash the flag on screen with the current settings.

The background-item prompt is the one that keeps the flash running. Seeing the saved shortcut as a key also needs Accessibility: open that list with `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"` and add **Superwhisper Language Flash** from `~/Library/Application Support/superwhisper-swiftbar/bin/`. That is the background item, separate from the Language Flash window. A recording still flashes without that permission, which covers a second key that Superwhisper starts by another path.

The same settings can still be changed from the terminal. Both write `~/Library/Application Support/superwhisper-swiftbar/flag-flash-settings.json`.

```bash
~/.local/bin/flag-flash settings
~/.local/bin/flag-flash set width 10
~/.local/bin/flag-flash set opacity 50
~/.local/bin/flag-flash set seconds 0.3
~/.local/bin/flag-flash --preview en
```

`width` is the percent of the screen width (2–80). `opacity` is the percent visible (5–100). `seconds` is how long the flag stays up (0.05–5).

The flash is a login item. After a restart it starts again when you log in, not before the login screen. The Language Flash window shows **Running** or **Not running**. From the terminal:

```bash
~/.local/bin/flag-flash status
```

Log: `~/Library/Application Support/superwhisper-swiftbar/flag-flash.log`

### 4. Keyboard toggle (F3) without breaking volume keys

macOS cannot make only F3 a standard function key. Use BetterTouchTool only (no Karabiner):

1. Turn **Use F1, F2, etc. keys as standard function keys** **on** so bare **F3** reaches BTT.
2. BTT global shortcut **F3** → Run Apple Script (async):

   ```applescript
   do shell script "/Users/YOUR_USERNAME/.local/bin/cycle-superwhisper-mode"
   ```

3. Because step 1 would otherwise break the media row, also add BTT shortcuts for the standard Apple keys (everything except F3):
   - **F1 / F2** → Brightness down / up  
   - **F4** → Spotlight (⌘Space)  
   - **F5** → Dictation  
   - **F6** → Do Not Disturb / Focus  
   - **F7 / F8 / F9** → Previous / Play-Pause / Next  
   - **F10 / F11 / F12** → Mute / Volume down / up  

4. Disable macOS **Show Desktop** on F11 (System Settings → Keyboard → Keyboard Shortcuts → Mission Control), or let `ensure-btt-f3.sh` turn off symbolic hotkeys 36/37 — otherwise F11 never reaches BTT’s Volume Down.

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
  flag-flash.log                              # runtime
  flag-flash-settings.json                    # size, opacity, time
  bin/
    sound-server.swift
    Superwhisper Mode Sounds.app/
    Superwhisper Language Flash.app/          # background flash

/Applications/Language Flash.app              # settings window, flag icon

~/.local/bin/
  cycle-superwhisper-mode -> …/cycle-superwhisper-mode.sh
  switch-superwhisper-mode -> …/switch-superwhisper-mode.sh
  flag-flash -> …/Superwhisper Language Flash.app/Contents/MacOS/…
```





## Important: keep the SwiftBar plugin folder clean

Only put actual SwiftBar plugins in your SwiftBar plugin directory (e.g. `~/Documents/swiftbar`).

Sounds, binaries, and helper scripts live in:

`~/Library/Application Support/superwhisper-swiftbar/`

If non-plugin files sit in the SwiftBar folder, they show up as broken `?` menu bar items.

Hotkeys and SwiftBar actions should call space-free symlinks in `~/.local/bin/` (`cycle-superwhisper-mode`, `switch-superwhisper-mode`), because paths under `Application Support` break AppleScript/`bash=` on the space.

## Persistence across reboots

These LaunchAgents keep things working after restart:

1. **Superwhisper Mode Sounds** — preloads cue audio
2. **Superwhisper Language Flash** — flashes the active language when the dictation key is pressed. Source: [bin/flag-flash.swift](bin/flag-flash.swift)
3. **ensure-superwhisper-f3** (optional, disabled by default) — can recreate the F3 shortcut at login; left off because an earlier hourly version spawned duplicates

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
