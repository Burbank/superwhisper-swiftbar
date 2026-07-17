# superwhisper-swiftbar

A [SwiftBar](https://swiftbar.app) plugin that shows your active [superwhisper](https://superwhisper.com) mode in the macOS menu bar — and lets you switch modes with a click or a keyboard shortcut.

If you use superwhisper with multiple modes (e.g. one per language), this gives you a persistent at-a-glance indicator of which mode is currently selected, plus a quick way to switch without interrupting dictation.

## Features

- Displays the active mode name in the menu bar (emoji, text, whatever you named it)
- Click any inactive mode in the dropdown to switch instantly
- Optional keyboard cycle script for BetterTouchTool (e.g. F3)
- Uses superwhisper's official `superwhisper://mode?key=` deep link API
- Reads mode configs from `~/Documents/superwhisper/modes/*.json` — always in sync
- Mode switches use `open -g` so your current app stays focused
- Updates every 2 seconds

## How it works

superwhisper stores mode configurations as JSON files in `~/Documents/superwhisper/modes/`. Each file contains the mode's display name, internal key, language, and settings. The plugin reads these files, checks which mode is active via superwhisper's preferences, and renders the menu bar.

Switching opens `superwhisper://mode?key=MODE_KEY` in the background (`open -g`), so Superwhisper changes mode without coming to the foreground.

## Requirements

- macOS 13.3+
- [superwhisper](https://superwhisper.com) installed (v2.10+)
- [SwiftBar](https://swiftbar.app) installed
- `python3` (ships with macOS)

## Installation

1. **Install SwiftBar** if you haven't already:

   ```bash
   brew install --cask swiftbar
   ```

   Or download from [GitHub releases](https://github.com/swiftbar/SwiftBar/releases/latest).

2. **Launch SwiftBar** and choose a plugin directory when prompted (e.g. `~/Documents/swiftbar`).

3. **Copy the plugin** into your SwiftBar plugin directory:

   ```bash
   PLUGIN_DIR="$(defaults read com.ameba.SwiftBar PluginDirectory)"
   curl -fsSL https://raw.githubusercontent.com/Burbank/superwhisper-swiftbar/main/superwhisper-mode.2s.sh \
     -o "$PLUGIN_DIR/superwhisper-mode.2s.sh"
   chmod +x "$PLUGIN_DIR/superwhisper-mode.2s.sh"
   ```

4. SwiftBar picks it up automatically. If not, click the SwiftBar icon and choose **Refresh All**.

## Tip: name your modes with flag emoji

Renaming your superwhisper modes to flag emoji (🇺🇸, 🇳🇱, 🇪🇸, …) makes for a compact, instantly recognizable menu bar indicator.

## Keyboard toggle (BetterTouchTool)

`cycle-superwhisper-mode.sh` advances to the next mode in `~/Documents/superwhisper/modes/` (stable alphabetical order by filename). With two modes it toggles; with three or more it cycles through all of them. Focus stays on the app you were using.

### Setup in BetterTouchTool

1. Install the cycle script:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Burbank/superwhisper-swiftbar/main/cycle-superwhisper-mode.sh \
     -o ~/Documents/swiftbar/cycle-superwhisper-mode.sh
   chmod +x ~/Documents/swiftbar/cycle-superwhisper-mode.sh
   ```

2. Open **BetterTouchTool** → **Keyboard Shortcuts** under **All Apps**.
3. If F3 already does something else (e.g. **Show Desktop**), edit that trigger instead of adding a second one.
4. Set the action to **Run Apple Script (async)** (or **Execute Shell Script / Task**):

   ```applescript
   do shell script "/Users/YOUR_USERNAME/Documents/swiftbar/cycle-superwhisper-mode.sh"
   ```

### Using F3 without holding Fn

macOS often maps bare F3 to Mission Control / Show Desktop. Options:

- **System Settings → Keyboard → Keyboard Shortcuts → Function Keys** → enable **Use F1, F2, etc. keys as standard function keys**, **or**
- Remap function keys in BetterTouchTool's keyboard settings

Also make sure no second F3 trigger is still bound to Show Desktop / Mission Control.

## Refresh interval

The filename `superwhisper-mode.2s.sh` tells SwiftBar to run the script every 2 seconds. Rename it to adjust — e.g. `superwhisper-mode.5s.sh`.

## Related

- [superwhisper docs: Switching Modes](https://superwhisper.com/docs/modes/switching-modes)
- [Raycast extension for superwhisper](https://www.raycast.com/nchudleigh/superwhisper)
- [Alfred workflow for superwhisper](https://github.com/ognistik/alfred-superwhisper)

## License

MIT
