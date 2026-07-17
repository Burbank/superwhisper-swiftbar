# superwhisper-swiftbar

A [SwiftBar](https://swiftbar.app) plugin that shows your active [superwhisper](https://superwhisper.com) mode in the macOS menu bar — and lets you switch modes with a click.

If you use superwhisper with multiple modes (e.g. one per language), this gives you a persistent at-a-glance indicator of which mode is currently selected, plus a quick way to switch.

## Features

- Displays the active mode name in the menu bar (emoji, text, whatever you named it)
- Click to see all modes — click any inactive mode to switch to it instantly
- Uses superwhisper's official `superwhisper://mode?key=` deep link API for real mode switching
- Reads mode configs directly from `~/Documents/superwhisper/modes/*.json` — always in sync, no caching
- Updates every 2 seconds

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

## Refresh interval

The filename `superwhisper-mode.2s.sh` tells SwiftBar to run the script every 2 seconds. Rename the file to adjust — e.g. `superwhisper-mode.5s.sh` for every 5 seconds.

## Related

- [superwhisper docs: Switching Modes](https://superwhisper.com/docs/modes/switching-modes)
- [Raycast extension for superwhisper](https://www.raycast.com/nchudleigh/superwhisper)
- [Alfred workflow for superwhisper](https://github.com/ognistik/alfred-superwhisper)

## License

MIT
