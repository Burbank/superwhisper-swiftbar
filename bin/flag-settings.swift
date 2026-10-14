// flag-settings.swift — settings window for the Superwhisper language flag.
// Project: README.md#language-flag-flash
//
// Writes the same file the background flash reads on the next dictation:
// ~/Library/Application Support/superwhisper-swiftbar/flag-flash-settings.json
// Keys match FlagSettings in flag-flash.swift: widthPercent, opacityPercent, seconds.

import AppKit
import Darwin
import ServiceManagement

private let launchAgentLabel = "com.burbank.superwhisper-flag-flash"
private let agentPlistName = "com.burbank.superwhisper-flag-flash.plist"

private struct FlagSettings: Codable {
    var widthPercent: Double = 10
    var opacityPercent: Double = 50
    var seconds: Double = 0.3

    static func load() -> FlagSettings {
        let url = settingsFileURL()
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(FlagSettings.self, from: data) else {
            return FlagSettings()
        }
        return decoded.clamped()
    }

    func save() throws {
        let url = settingsFileURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(clamped()).write(to: url, options: .atomic)
    }

    func clamped() -> FlagSettings {
        var copy = self
        copy.widthPercent = min(80, max(2, widthPercent))
        copy.opacityPercent = min(100, max(5, opacityPercent))
        copy.seconds = min(5, max(0.05, seconds))
        return copy
    }

    func matches(_ other: FlagSettings) -> Bool {
        abs(widthPercent - other.widthPercent) < 0.001
            && abs(opacityPercent - other.opacityPercent) < 0.001
            && abs(seconds - other.seconds) < 0.001
    }
}

private func settingsFileURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/superwhisper-swiftbar/flag-flash-settings.json")
}

private func agentExecutable() -> String? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let bundled = Bundle.main.bundleURL
        .appendingPathComponent("Contents/MacOS/Language Flash Agent").path
    let candidates = [
        bundled,
        "\(home)/.local/bin/flag-flash",
        "\(home)/Library/Application Support/superwhisper-swiftbar/bin/Superwhisper Language Flash.app/Contents/MacOS/Superwhisper Language Flash",
    ]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
}

private func embeddedAgentPlistExists() -> Bool {
    let url = Bundle.main.bundleURL
        .appendingPathComponent("Contents/Library/LaunchAgents/\(agentPlistName)")
    return FileManager.default.fileExists(atPath: url.path)
}

private func launchAgentPlist() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
}

private func runCommand(_ path: String, _ arguments: [String]) -> (Int32, String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = arguments
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        return (1, error.localizedDescription)
    }
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (task.terminationStatus, output)
}

private func xmlText(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

private struct AgentProcessStatus {
    var loaded = false
    var running = false
}

private func agentProcessStatus() -> AgentProcessStatus {
    let result = runCommand("/bin/launchctl", ["print", "gui/\(getuid())/\(launchAgentLabel)"])
    let loaded = result.0 == 0
    return AgentProcessStatus(loaded: loaded, running: loaded && result.1.contains("state = running"))
}

private enum PreviewKind: Int {
    case netherlands
    case unitedStates
    case spain

    var token: String {
        switch self {
        case .netherlands: return "nl"
        case .unitedStates: return "en"
        case .spain: return "es"
        }
    }

    var aspect: CGFloat {
        switch self {
        case .unitedStates: return 1.9
        case .netherlands, .spain: return 1.5
        }
    }
}

private func nsColor(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

private func starPath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let inner = radius * 0.381966
    var angle = CGFloat.pi / 2
    let step = CGFloat.pi / 5
    for index in 0..<10 {
        let distance = index % 2 == 0 ? radius : inner
        let point = CGPoint(
            x: center.x + cos(angle) * distance,
            y: center.y + sin(angle) * distance
        )
        if index == 0 {
            path.move(to: point)
        } else {
            path.line(to: point)
        }
        angle -= step
    }
    path.close()
    return path
}

private final class ScreenPreview: NSView {
    var kind: PreviewKind = .unitedStates {
        didSet { needsDisplay = true }
    }
    var widthPercent: CGFloat = 10 {
        didSet { needsDisplay = true }
    }
    var opacity: CGFloat = 0.5 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let screen = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        nsColor(0x2A2E38).setFill()
        screen.fill()

        let inset = bounds.insetBy(dx: 16, dy: 16)
        var width = inset.width * widthPercent / 100
        var height = width / kind.aspect
        let maxHeight = inset.height * 0.86
        if height > maxHeight {
            height = maxHeight
            width = height * kind.aspect
        }
        let flag = NSRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.cgContext.setAlpha(opacity)
        drawFlag(in: flag)
        context.restoreGraphicsState()
    }

    private func drawFlag(in rect: NSRect) {
        switch kind {
        case .netherlands:
            stripes([(nsColor(0xAE1C28), 1), (NSColor.white, 1), (nsColor(0x21468B), 1)], in: rect)
        case .spain:
            stripes([(nsColor(0xAA151B), 1), (nsColor(0xF1BF00), 2), (nsColor(0xAA151B), 1)], in: rect)
        case .unitedStates:
            unitedStates(in: rect)
        }
    }

    private func stripes(_ bands: [(NSColor, CGFloat)], in rect: NSRect) {
        let total = bands.reduce(CGFloat(0)) { $0 + $1.1 }
        var y = rect.maxY
        for (color, weight) in bands {
            let height = rect.height * weight / total
            y -= height
            color.setFill()
            NSRect(x: rect.minX, y: y, width: rect.width, height: height).fill()
        }
    }

    private func unitedStates(in rect: NSRect) {
        let stripeHeight = rect.height / 13
        for index in 0..<13 {
            let color = index % 2 == 0 ? nsColor(0xB22234) : NSColor.white
            color.setFill()
            let y = rect.maxY - CGFloat(index + 1) * stripeHeight
            NSRect(x: rect.minX, y: y, width: rect.width, height: stripeHeight).fill()
        }
        let canton = NSRect(
            x: rect.minX,
            y: rect.maxY - 7 * stripeHeight,
            width: rect.width * 0.4,
            height: 7 * stripeHeight
        )
        nsColor(0x3C3B6E).setFill()
        canton.fill()
        let rowHeight = canton.height / 9
        let columnWidth = canton.width / 6
        let radius = min(rowHeight, columnWidth) * 0.36
        NSColor.white.setFill()
        for row in 0..<9 {
            let count = row % 2 == 0 ? 6 : 5
            let y = canton.maxY - (CGFloat(row) + 0.5) * rowHeight
            for column in 0..<count {
                let x = count == 6
                    ? canton.minX + (CGFloat(column) + 0.5) * columnWidth
                    : canton.minX + (CGFloat(column) + 1) * columnWidth
                starPath(center: CGPoint(x: x, y: y), radius: radius).fill()
            }
        }
    }
}

private final class DotView: NSView {
    var running = false {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 10, height: 10) }

    override func draw(_ dirtyRect: NSRect) {
        (running ? NSColor.systemGreen : NSColor.systemOrange).setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
    }
}

private final class SettingsApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let preview = ScreenPreview(frame: .zero)
    private let segments = NSSegmentedControl(
        labels: ["Dutch", "English", "Spanish"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let sizeSlider = NSSlider(value: 10, minValue: 2, maxValue: 80, target: nil, action: nil)
    private let opacitySlider = NSSlider(value: 50, minValue: 5, maxValue: 100, target: nil, action: nil)
    private let timeSlider = NSSlider(value: 0.3, minValue: 0.05, maxValue: 2, target: nil, action: nil)
    private let sizeValue = NSTextField(labelWithString: "10%")
    private let opacityValue = NSTextField(labelWithString: "50%")
    private let timeValue = NSTextField(labelWithString: "0.30 seconds")
    private let dot = DotView(frame: .zero)
    private let statusLabel = NSTextField(labelWithString: "Checking…")
    private let startButton = NSButton(title: "Start", target: nil, action: nil)
    private let loginCheck = NSButton(checkboxWithTitle: "Start when you log in", target: nil, action: nil)
    private let loginSettingsButton = NSButton(title: "Login Items…", target: nil, action: nil)
    private let note = NSTextField(wrappingLabelWithString: "")
    private var timer: Timer?
    private var didSave = false
    private var running = false
    private var updatingLoginCheck = false
    private var loginHint: String?
    private var failure: String?
    private var saveError: String?
    private var saveWork: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        loadControls()
        wireActions()
        ensureLoginItem()
        refreshStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "Quit Language Flash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        NSApp.mainMenu = main
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Language Flash"
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 600))
        window.contentView = content

        let subtitle = NSTextField(wrappingLabelWithString: "Size is the percent of the screen width. Opacity is how solid the flag is. Time is how long it stays up.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = NSFont.systemFont(ofSize: 13)
        subtitle.preferredMaxLayoutWidth = 480
        place(subtitle, NSRect(x: 20, y: 536, width: 480, height: 44), in: content)

        place(preview, NSRect(x: 20, y: 372, width: 480, height: 152), in: content)

        segments.segmentStyle = .automatic
        segments.selectedSegment = 1
        place(segments, NSRect(x: 110, y: 344, width: 300, height: 24), in: content)

        addSliderRow(
            title: "Size",
            slider: sizeSlider,
            value: sizeValue,
            y: 302,
            in: content
        )
        addSliderRow(
            title: "Opacity",
            slider: opacitySlider,
            value: opacityValue,
            y: 266,
            in: content
        )
        addSliderRow(
            title: "Time",
            slider: timeSlider,
            value: timeValue,
            y: 230,
            in: content
        )

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 8
        for (title, action) in [
            ("Preview Dutch", #selector(previewDutch)),
            ("Preview English", #selector(previewEnglish)),
            ("Preview Spanish", #selector(previewSpanish)),
        ] as [(String, Selector)] {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded
            buttons.addArrangedSubview(button)
        }
        place(buttons, NSRect(x: 20, y: 180, width: 480, height: 32), in: content)

        loginCheck.font = NSFont.systemFont(ofSize: 13)
        place(loginCheck, NSRect(x: 18, y: 140, width: 280, height: 24), in: content)
        loginSettingsButton.bezelStyle = .rounded
        loginSettingsButton.target = self
        loginSettingsButton.action = #selector(openLoginItems)
        place(loginSettingsButton, NSRect(x: 340, y: 136, width: 160, height: 32), in: content)

        dot.frame = NSRect(x: 20, y: 108, width: 10, height: 10)
        content.addSubview(dot)
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        place(statusLabel, NSRect(x: 38, y: 100, width: 330, height: 22), in: content)
        startButton.bezelStyle = .rounded
        startButton.target = self
        startButton.action = #selector(startOrRestart)
        place(startButton, NSRect(x: 380, y: 94, width: 120, height: 32), in: content)

        note.font = NSFont.systemFont(ofSize: 13)
        note.textColor = .labelColor
        note.preferredMaxLayoutWidth = 480
        place(note, NSRect(x: 20, y: 28, width: 480, height: 46), in: content)

        let path = NSTextField(wrappingLabelWithString: displayedSettingsPath())
        path.font = NSFont.systemFont(ofSize: 11)
        path.textColor = .tertiaryLabelColor
        place(path, NSRect(x: 20, y: 8, width: 480, height: 18), in: content)
    }

    private func addSliderRow(title: String, slider: NSSlider, value: NSTextField, y: CGFloat, in content: NSView) {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        place(label, NSRect(x: 20, y: y, width: 64, height: 20), in: content)
        slider.isContinuous = true
        place(slider, NSRect(x: 88, y: y - 2, width: 268, height: 24), in: content)
        value.alignment = .right
        value.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        place(value, NSRect(x: 364, y: y, width: 136, height: 20), in: content)
    }

    private func place(_ view: NSView, _ frame: NSRect, in content: NSView) {
        view.frame = frame
        content.addSubview(view)
    }

    private func loadControls() {
        let settings = FlagSettings.load()
        sizeSlider.doubleValue = settings.widthPercent
        opacitySlider.doubleValue = settings.opacityPercent
        if settings.seconds > timeSlider.maxValue {
            timeSlider.maxValue = min(5, settings.seconds)
        }
        timeSlider.doubleValue = settings.seconds
        applyToPreview()
    }

    private func wireActions() {
        segments.target = self
        segments.action = #selector(segmentChanged(_:))
        for slider in [sizeSlider, opacitySlider, timeSlider] {
            slider.target = self
            slider.action = #selector(sliderMoved(_:))
        }
        loginCheck.target = self
        loginCheck.action = #selector(loginChanged(_:))
    }

    private func currentSettings() -> FlagSettings {
        var settings = FlagSettings()
        settings.widthPercent = sizeSlider.doubleValue.rounded()
        settings.opacityPercent = opacitySlider.doubleValue.rounded()
        settings.seconds = ((timeSlider.doubleValue / 0.05).rounded() * 0.05 * 100).rounded() / 100
        return settings.clamped()
    }

    private func applyToPreview() {
        let settings = currentSettings()
        if segments.selectedSegment == 0 {
            preview.kind = .netherlands
        } else if segments.selectedSegment == 2 {
            preview.kind = .spain
        } else {
            preview.kind = .unitedStates
        }
        preview.widthPercent = CGFloat(settings.widthPercent)
        preview.opacity = CGFloat(settings.opacityPercent / 100)
        sizeValue.stringValue = "\(Int(settings.widthPercent))%"
        opacityValue.stringValue = "\(Int(settings.opacityPercent))%"
        timeValue.stringValue = String(format: "%.2f seconds", settings.seconds)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.save()
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func save() {
        let settings = currentSettings()
        do {
            try settings.save()
            let loaded = FlagSettings.load()
            didSave = true
            if loaded.matches(settings) {
                saveError = nil
                refreshNote()
            } else {
                saveError = "The settings file did not keep that change."
                refreshNote()
            }
        } catch {
            saveError = "Could not save: \(error.localizedDescription)"
            refreshNote()
        }
    }

    private func refreshNote() {
        if running {
            failure = nil
        }
        if let failure, !running {
            note.stringValue = failure
            note.textColor = .systemRed
            return
        }
        if let saveError {
            note.stringValue = saveError
            note.textColor = .systemRed
            return
        }
        if let loginHint {
            note.stringValue = loginHint
            note.textColor = .labelColor
            return
        }
        note.textColor = .labelColor
        let installed = embeddedAgentPlistExists() || FileManager.default.fileExists(atPath: launchAgentPlist().path)
        if !installed {
            note.stringValue = "The background flash is not installed yet. Run bin/install-flag-flash.sh from the project folder, then come back."
            return
        }
        if didSave && running {
            note.stringValue = "Saved. The next dictation uses this. The background flash does not need a restart."
        } else if didSave {
            note.stringValue = "Saved. Start the flash so the next dictation shows the flag."
        } else if running {
            note.stringValue = "The flash is running. A change here is used the next time you dictate."
        } else {
            note.stringValue = "The flash is not running, so dictation will not show a flag until you start it."
        }
    }

    private func refreshStatus() {
        let process = agentProcessStatus()
        refreshLoginCheck(agentLoaded: process.loaded)
        let installed = embeddedAgentPlistExists() || FileManager.default.fileExists(atPath: launchAgentPlist().path)
        running = process.running
        dot.running = running
        if !installed {
            statusLabel.stringValue = "Not installed"
            startButton.title = "Start"
            startButton.isEnabled = false
        } else if running {
            statusLabel.stringValue = "Running"
            startButton.title = "Restart"
            startButton.isEnabled = true
        } else {
            statusLabel.stringValue = "Not running"
            startButton.title = "Start"
            startButton.isEnabled = true
            startButton.keyEquivalent = "\r"
        }
        if running {
            startButton.keyEquivalent = ""
        }
        refreshNote()
    }

    private func displayedSettingsPath() -> String {
        let path = settingsFileURL().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func flash(_ kind: PreviewKind) {
        segments.selectedSegment = kind.rawValue
        applyToPreview()
        saveWork?.cancel()
        save()
        guard let executable = agentExecutable() else {
            note.stringValue = "The background flash is not installed, so there is nothing to preview on screen."
            note.textColor = .systemRed
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = ["--preview", kind.token]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            note.stringValue = "Could not preview: \(error.localizedDescription)"
            note.textColor = .systemRed
        }
    }

    @objc private func sliderMoved(_: NSSlider) {
        applyToPreview()
        scheduleSave()
    }

    @objc private func segmentChanged(_: NSSegmentedControl) {
        applyToPreview()
    }

    @objc private func previewDutch() { flash(.netherlands) }
    @objc private func previewEnglish() { flash(.unitedStates) }
    @objc private func previewSpanish() { flash(.spain) }

    private func ensureLoginItem() {
        guard #available(macOS 13.0, *) else {
            installLegacyAgent()
            return
        }
        guard embeddedAgentPlistExists() else {
            installLegacyAgent()
            return
        }
        let service = SMAppService.agent(plistName: agentPlistName)
        if service.status == .enabled || service.status == .requiresApproval || agentProcessStatus().loaded {
            return
        }
        do {
            try service.register()
        } catch {
            installLegacyAgent()
        }
    }

    private func installLegacyAgent() {
        guard let executable = agentExecutable() else {
            failure = "Could not find the background flash inside Language Flash."
            return
        }
        let plist = launchAgentPlist()
        let log = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/superwhisper-swiftbar/flag-flash.log")
            .path
        let body = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(launchAgentLabel)</string>
          <key>AssociatedBundleIdentifiers</key>
          <array>
            <string>com.burbank.language-flash</string>
          </array>
          <key>ProgramArguments</key>
          <array>
            <string>\(xmlText(executable))</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>StandardErrorPath</key>
          <string>\(xmlText(log))</string>
          <key>StandardOutPath</key>
          <string>\(xmlText(log))</string>
          <key>BurbankManagedAgent</key>
          <true/>
        </dict>
        </plist>
        """
        do {
            try FileManager.default.createDirectory(
                at: plist.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(body.utf8).write(to: plist, options: .atomic)
        } catch {
            failure = "Could not save the login item. \(error.localizedDescription)"
            return
        }
        let uid = getuid()
        let domain = "gui/\(uid)"
        let service = "\(domain)/\(launchAgentLabel)"
        _ = runCommand("/bin/launchctl", ["bootout", service])
        let bootstrap = runCommand("/bin/launchctl", ["bootstrap", domain, plist.path])
        _ = runCommand("/bin/launchctl", ["enable", service])
        _ = runCommand("/bin/launchctl", ["kickstart", "-k", service])
        if bootstrap.0 != 0 && !agentProcessStatus().loaded {
            let detail = bootstrap.1.trimmingCharacters(in: .whitespacesAndNewlines)
            failure = detail.isEmpty
                ? "Could not add Language Flash to login items."
                : "Could not add Language Flash to login items. \(detail)"
        }
    }

    private func removeLegacyAgent() {
        let plist = launchAgentPlist()
        let uid = getuid()
        let service = "gui/\(uid)/\(launchAgentLabel)"
        _ = runCommand("/bin/launchctl", ["bootout", service])
        _ = runCommand("/bin/launchctl", ["disable", service])
        guard let text = try? String(contentsOf: plist, encoding: .utf8),
              text.contains("BurbankManagedAgent") else {
            return
        }
        try? FileManager.default.removeItem(at: plist)
    }

    private func refreshLoginCheck(agentLoaded: Bool) {
        guard #available(macOS 13.0, *) else {
            loginCheck.isEnabled = false
            loginHint = "This macOS is too old to show Language Flash in Login Items."
            return
        }
        guard embeddedAgentPlistExists() else {
            loginCheck.isEnabled = false
            loginHint = nil
            return
        }
        loginCheck.isEnabled = true
        let service = SMAppService.agent(plistName: agentPlistName)
        updatingLoginCheck = true
        switch service.status {
        case .enabled:
            loginCheck.state = .on
            loginHint = nil
        case .requiresApproval:
            loginCheck.state = .on
            loginHint = "Allow Language Flash in System Settings → General → Login Items & Extensions. Login Items… opens that list."
        case .notRegistered, .notFound:
            loginCheck.state = agentLoaded ? .on : .off
            loginHint = nil
        @unknown default:
            loginCheck.state = .off
            loginHint = nil
        }
        updatingLoginCheck = false
    }

    @objc private func loginChanged(_ sender: NSButton) {
        guard !updatingLoginCheck else { return }
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.agent(plistName: agentPlistName)
        failure = nil
        if sender.state == .on {
            do {
                if service.status == .notRegistered || service.status == .notFound {
                    try service.register()
                }
            } catch {
                installLegacyAgent()
            }
            if service.status != .enabled && service.status != .requiresApproval && !agentProcessStatus().loaded {
                installLegacyAgent()
            }
        } else {
            if service.status == .enabled || service.status == .requiresApproval {
                try? service.unregister()
            }
            removeLegacyAgent()
        }
        refreshStatus()
    }

    @objc private func openLoginItems() {
        guard #available(macOS 13.0, *) else { return }
        SMAppService.openSystemSettingsLoginItems()
    }

    @objc private func startOrRestart() {
        let uid = getuid()
        let service = "gui/\(uid)/\(launchAgentLabel)"
        startButton.isEnabled = false
        failure = nil
        ensureLoginItem()
        _ = runCommand("/bin/launchctl", ["enable", service])
        let kick = runCommand("/bin/launchctl", ["kickstart", "-k", service])
        refreshStatus()
        if !running {
            let detail = kick.1
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            if detail.isEmpty {
                failure = "Could not start the flash. Turn on “Start when you log in”, then click Start again."
            } else {
                failure = "Could not start the flash. \(detail)"
            }
            refreshNote()
        }
        startButton.isEnabled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refreshStatus()
        }
    }
}

private let app = NSApplication.shared
private let controller = SettingsApp()
app.setActivationPolicy(.regular)
app.delegate = controller
app.run()
