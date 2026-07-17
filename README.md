# superwhisper-swiftbar

A [SwiftBar](https://swiftbar.app) plugin that shows your active [superwhisper](https://superwhisper.com) mode in the macOS menu bar — and lets you switch modes with a click.

If you use superwhisper with multiple modes (e.g. one per language), this gives you a persistent at-a-glance indicator of which mode is currently selected, plus a quick way to switch.

## Features

- Displays the active mode name in the menu bar (emoji, text, whatever you named it)
- Click to see all modes — click any inactive mode to switch to it instantly
- Uses superwhisper's official `superwhisper://mode?key=` deep link API for real mode switching
- Reads mode configs directly from `~/Documents/superwhisper/modes/*.json` — always in sync, no caching
- Updates every 2 seconds
- Optional F3 toggle via BetterTouchTool to cycle through language modes

## How it works

superwhisper stores mode configurations as JSON files in `~/Documents/superwhisper/modes/`. Each file contains the mode's display name, internal key, language, and settings. The plugin reads these files, checks which mode is active via superwhisper's preferences, and renders the menu bar.

When you click an inactive mode in the dropdown, it opens the deep link `superwhisper://mode?key=MODE_KEY`, which tells superwhisper to switch modes through its official API.

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
   curl -fsSL https://raw.githubusercontent.com/Burbank/superwhisper-swiftbar/main/superwhisper-mode.2s.sh \
     -o "$(defaults read com.ameba.SwiftBar PluginDirectory)/superwhisper-mode.2s.sh"
   chmod +x "$(defaults read com.ameba.SwiftBar PluginDirectory)/superwhisper-mode.2s.sh"
   ```

4. SwiftBar picks it up automatically. If not, click the SwiftBar icon and choose **Refresh All**.

## Tip: name your modes with flag emoji

Renaming your superwhisper modes to flag emoji (🇺🇸, 🇳🇱, 🇪🇸, …) makes for a compact, instantly recognizable menu bar indicator that takes up minimal space.

## Keyboard toggle (BetterTouchTool)

`cycle-superwhisper-mode.sh` advances to the next mode in `~/Documents/superwhisper/modes/` (stable alphabetical order). With two modes it toggles; with three or more it cycles through all of them.

### Setup in BetterTouchTool

1. Install the cycle script next to the plugin (or anywhere you prefer):

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Burbank/superwhisper-swiftbar/main/cycle-superwhisper-mode.sh \
     -o ~/Documents/swiftbar/cycle-superwhisper-mode.sh
   chmod +x ~/Documents/swiftbar/cycle-superwhisper-mode.sh
   ```

2. Open **BetterTouchTool** → select **Keyboard Shortcuts** (left sidebar) under the **All Apps** / global section.
3. Click **+** to add a new shortcut, then click **Click here to record shortcut** and press **F3**.
4. Add an action: **Execute Shell Script / Task** (or **Run Apple Script (async)**).
5. Point it at the script:

   ```bash
   /Users/YOUR_USERNAME/Documents/swiftbar/cycle-superwhisper-mode.sh
   ```

   Or as AppleScript:

   ```applescript
   do shell script "/Users/YOUR_USERNAME/Documents/swiftbar/cycle-superwhisper-mode.sh"
   ```

### Using F3 without holding Fn

macOS treats F3 as Mission Control by default. Pick one:

- **System Settings → Keyboard → Keyboard Shortcuts → Function Keys** → enable **Use F1, F2, etc. keys as standard function keys** (affects all F-keys; hold Fn for Mission Control / brightness / etc.), **or**
- In **BetterTouchTool → Settings → Keyboard**, enable the option that remaps function keys to F1–F12 while BTT is running (wording varies by BTT version).

Then record **F3** again in the BTT trigger if needed.

## Refresh interval

The filename `superwhisper-mode.2s.sh` tells SwiftBar to run the script every 2 seconds. Rename the file to adjust — e.g. `superwhisper-mode.5s.sh` for every 5 seconds.

## Related

- [superwhisper docs: Switching Modes](https://superwhisper.com/docs/modes/switching-modes)
- [Raycast extension for superwhisper](https://www.raycast.com/nchudleigh/superwhisper)
- [Alfred workflow for superwhisper](https://github.com/ognistik/alfred-superwhisper)

## License

MIT
