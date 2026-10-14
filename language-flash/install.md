# Installing Language Flash

The short version is on the [Language Flash page](README.md). This page is the rest.

Keep the project folder outside iCloud. A pull inside `Mobile Documents` can stop with `mmap failed: Operation canceled`, and then the installer never runs.

First install, from a copy outside iCloud:

```bash
mkdir -p "$HOME/.local/src"
git clone --branch cursor/dictation-flag-flash-f3a2 --single-branch https://github.com/Burbank/superwhisper-swiftbar.git "$HOME/.local/src/superwhisper-swiftbar"
"$HOME/.local/src/superwhisper-swiftbar/bin/install-flag-flash.sh"
```

Later updates:

```bash
cd "$HOME/.local/src/superwhisper-swiftbar" && git pull && ./bin/install-flag-flash.sh
```

The app goes in `/Applications`, next to your other apps. If that folder is not writable, it uses `~/Applications`. The script prints the path.

On a Mac that already has the Developer ID certificate used for yourMark, the installer signs Language Flash and sends it to Apple for notarization, using the notary login `yourmark-notary`. That takes a few minutes. Without that certificate, the app still installs.

Until you edit **Languages…**, Dutch, English, and Spanish are the starting flags. A row that began as a Superwhisper mode keeps following that mode after you rename it. A row you add follows a mode with the same name. `NL`, `US`, and `ES` are drawn. Any other country code uses that country’s flag.

The same size, opacity, and time can be set in Terminal. Both write `~/Library/Application Support/superwhisper-swiftbar/flag-flash-settings.json`.

```bash
~/.local/bin/flag-flash settings
~/.local/bin/flag-flash set width 10
~/.local/bin/flag-flash set opacity 50
~/.local/bin/flag-flash set seconds 0.3
~/.local/bin/flag-flash status
```

Log: `~/Library/Application Support/superwhisper-swiftbar/flag-flash.log`
