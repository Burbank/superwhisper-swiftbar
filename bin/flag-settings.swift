// flag-settings.swift — settings window for the Superwhisper language flag.
// Project: README.md#language-flag-flash
//
// Writes the same file the background flash reads on the next dictation:
// ~/Library/Application Support/superwhisper-swiftbar/flag-flash-settings.json
// Keys match FlagSettings in flag-flash.swift: widthPercent, opacityPercent, seconds, languages.

import AppKit
import Darwin
import ServiceManagement

private let launchAgentLabel = "com.burbank.superwhisper-flag-flash"
private let agentPlistName = "com.burbank.superwhisper-flag-flash.plist"

private struct LanguageChoice: Codable, Equatable {
    var word: String = ""
    var flag: String = ""
    var modeKey: String = ""

    init(word: String = "", flag: String = "", modeKey: String = "") {
        self.word = word
        self.flag = flag
        self.modeKey = modeKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decodeIfPresent(String.self, forKey: .word) ?? ""
        flag = try container.decodeIfPresent(String.self, forKey: .flag) ?? ""
        modeKey = try container.decodeIfPresent(String.self, forKey: .modeKey) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case word, flag, modeKey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(word, forKey: .word)
        try container.encode(flag, forKey: .flag)
        try container.encode(modeKey, forKey: .modeKey)
    }
}

private struct FlagSettings: Codable {
    var widthPercent: Double = 10
    var opacityPercent: Double = 50
    var seconds: Double = 0.3
    /// Older per-mode country codes. Ignored once `languages` has been saved.
    var flags: [String: String] = [:]
    /// Nil until the user edits Languages. After that, this list is the only source of flags.
    var languages: [LanguageChoice]?

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        widthPercent = try container.decodeIfPresent(Double.self, forKey: .widthPercent) ?? 10
        opacityPercent = try container.decodeIfPresent(Double.self, forKey: .opacityPercent) ?? 50
        seconds = try container.decodeIfPresent(Double.self, forKey: .seconds) ?? 0.3
        flags = try container.decodeIfPresent([String: String].self, forKey: .flags) ?? [:]
        languages = try container.decodeIfPresent([LanguageChoice].self, forKey: .languages)
    }

    private enum CodingKeys: String, CodingKey {
        case widthPercent, opacityPercent, seconds, flags, languages
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(widthPercent, forKey: .widthPercent)
        try container.encode(opacityPercent, forKey: .opacityPercent)
        try container.encode(seconds, forKey: .seconds)
        try container.encode(flags, forKey: .flags)
        if let languages {
            try container.encode(languages, forKey: .languages)
        }
    }

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
            && flags == other.flags
            && languages == other.languages
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

private enum DrawnFlag {
    case netherlands
    case unitedStates
    case spain
    case emoji(String)
    case placeholder

    var aspect: CGFloat {
        switch self {
        case .unitedStates: return 1.9
        case .placeholder: return 2.2
        case .netherlands, .spain, .emoji: return 1.5
        }
    }
}

private func flagEmoji(countryCode: String) -> String {
    let letters = countryCode.uppercased()
    guard letters.count == 2 else { return countryCode }
    var scalars = String.UnicodeScalarView()
    for scalar in letters.unicodeScalars {
        guard let regional = Unicode.Scalar(127397 + scalar.value) else { return countryCode }
        scalars.append(regional)
    }
    return String(scalars)
}

private func drawnFlag(for sample: String) -> DrawnFlag {
    let trimmed = sample.trimmingCharacters(in: .whitespacesAndNewlines)
    switch trimmed.uppercased() {
    case "NL":
        return .netherlands
    case "US", "USA":
        return .unitedStates
    case "ES":
        return .spain
    case "":
        return .placeholder
    default:
        if trimmed.count == 2, trimmed.allSatisfy({ $0.isLetter }) {
            return .emoji(flagEmoji(countryCode: trimmed))
        }
        if trimmed.unicodeScalars.contains(where: { $0.value > 127 }) {
            return .emoji(trimmed)
        }
        return .placeholder
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
    /// Country code, emoji, or empty. The picture follows the user's first language.
    var sample: String = "" {
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

        let flagKind = drawnFlag(for: sample)
        let inset = bounds.insetBy(dx: 16, dy: 16)
        var width = inset.width * widthPercent / 100
        var height = width / flagKind.aspect
        let maxHeight = inset.height * 0.86
        if height > maxHeight {
            height = maxHeight
            width = height * flagKind.aspect
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
        drawFlag(flagKind, in: flag)
        context.restoreGraphicsState()
    }

    private func drawFlag(_ kind: DrawnFlag, in rect: NSRect) {
        switch kind {
        case .netherlands:
            stripes([(nsColor(0xAE1C28), 1), (NSColor.white, 1), (nsColor(0x21468B), 1)], in: rect)
        case .spain:
            stripes([(nsColor(0xAA151B), 1), (nsColor(0xF1BF00), 2), (nsColor(0xAA151B), 1)], in: rect)
        case .unitedStates:
            unitedStates(in: rect)
        case .emoji(let text):
            emoji(text, in: rect)
        case .placeholder:
            NSColor.white.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
        }
    }

    private func emoji(_ text: String, in rect: NSRect) {
        let size = min(rect.width, rect.height) * 0.92
        let font = NSFont(name: "Apple Color Emoji", size: size) ?? NSFont.systemFont(ofSize: size)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let bounds = string.boundingRect(
            with: NSSize(width: rect.width, height: rect.height * 2),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textRect = NSRect(
            x: rect.midX - rect.width / 2,
            y: rect.midY - bounds.height / 2,
            width: rect.width,
            height: bounds.height
        )
        string.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
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

private struct FlashMode {
    var key: String
    var name: String
    var language: String
}

private let countryCodes = [
    "NL", "US", "GB", "ES", "FR", "DE", "IT", "PT", "BR", "SE", "NO", "DK", "FI",
    "PL", "CZ", "AT", "CH", "BE", "IE", "GR", "TR", "RU", "UA", "JP", "CN", "KR",
    "IN", "TH", "VN", "ID", "SA", "AE", "IL", "ZA", "EG", "MX", "AR", "CA", "AU", "NZ",
]

private func builtinCountry(language: String, key: String) -> String {
    let lang = language.split(separator: "-").first.map { String($0).lowercased() } ?? ""
    let token = lang.isEmpty ? key.lowercased() : lang
    switch token {
    case "nl", "nld", "dutch", "super": return "NL"
    case "en", "eng", "english", "us", "usa", "default": return "US"
    case "es", "spa", "spanish": return "ES"
    default: return ""
    }
}

private func displayWord(for mode: FlashMode) -> String {
    let lang = mode.language.split(separator: "-").first.map { String($0).lowercased() } ?? ""
    let token = lang.isEmpty ? mode.key.lowercased() : lang
    switch token {
    case "nl", "nld", "dutch", "super": return "Dutch"
    case "en", "eng", "english", "us", "usa", "default": return "English"
    case "es", "spa", "spanish": return "Spanish"
    default: return mode.name
    }
}

private func normalizeFlag(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return nil }
    let upper = trimmed.uppercased()
    if upper == "UK" { return "GB" }
    if upper == "USA" { return "US" }
    if upper.count == 2, upper.allSatisfy({ $0.isLetter }) { return upper }
    if trimmed.unicodeScalars.contains(where: { $0.value > 127 }) { return trimmed }
    return nil
}

private func sampleFlag(from settings: FlagSettings) -> String {
    let languages = settings.languages ?? startingLanguages()
    return languages.compactMap { normalizeFlag($0.flag) }.first ?? ""
}

private func loadFlashModes() -> [FlashMode] {
    let domain = "com.superduper.superwhisper" as CFString
    CFPreferencesAppSynchronize(domain)
    func pref(_ key: String) -> String? {
        guard let value = CFPreferencesCopyAppValue(key as CFString, domain) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    var candidates: [URL] = []
    if let parent = pref("appFolderDirectory") {
        let parentURL = URL(fileURLWithPath: (parent as NSString).expandingTildeInPath)
        candidates.append(parentURL.appendingPathComponent("superwhisper"))
        candidates.append(parentURL)
    }
    candidates.append(home.appendingPathComponent("Documents/superwhisper"))
    candidates.append(home.appendingPathComponent("superwhisper"))
    let folder = candidates.first { url in
        var isDirectory: ObjCBool = false
        let modes = url.appendingPathComponent("modes")
        return FileManager.default.fileExists(atPath: modes.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
    guard let folder else { return [] }
    let directory = folder.appendingPathComponent("modes")
    guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
        return []
    }
    var modes: [FlashMode] = []
    for file in files where file.pathExtension.lowercased() == "json" {
        guard
            let data = try? Data(contentsOf: file),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { continue }
        let filename = file.deletingPathExtension().lastPathComponent
        let key = (object["key"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? filename
        let name = (object["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? key
        let language = object["language"] as? String ?? ""
        modes.append(FlashMode(key: key, name: name, language: language))
    }
    return modes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

private func savedFlag(for mode: FlashMode, flags: [String: String]) -> String {
    let lang = mode.language.split(separator: "-").first.map { String($0).lowercased() } ?? ""
    let candidates = [mode.key.lowercased(), lang, mode.name.lowercased()]
    for candidate in candidates where !candidate.isEmpty {
        if let value = flags[candidate], let code = normalizeFlag(value) {
            return code
        }
    }
    return builtinCountry(language: mode.language, key: mode.key)
}

private func startingLanguages() -> [LanguageChoice] {
    let settings = FlagSettings.load()
    if let languages = settings.languages {
        return languages
    }
    let modes = loadFlashModes()
    if modes.isEmpty {
        return [
            LanguageChoice(word: "Dutch", flag: "NL", modeKey: ""),
            LanguageChoice(word: "English", flag: "US", modeKey: ""),
            LanguageChoice(word: "Spanish", flag: "ES", modeKey: ""),
        ]
    }
    return modes.map { mode in
        LanguageChoice(
            word: displayWord(for: mode),
            flag: savedFlag(for: mode, flags: settings.flags),
            modeKey: mode.key
        )
    }
}

private final class LanguageEditor: NSObject, NSTextFieldDelegate, NSComboBoxDelegate {
    static let shared = LanguageEditor()

    private let rowHeight: CGFloat = 36
    private var panel: NSPanel?
    private var scroll: NSScrollView?
    private var entries: [LanguageChoice] = []
    private var wordFields: [NSTextField] = []
    private var flagFields: [NSComboBox] = []
    private var onPreview: ((String) -> Void)?
    private var onChange: (() -> Void)?
    private var focusNewRow = false

    func show(relativeTo parent: NSWindow?, preview: @escaping (String) -> Void, changed: @escaping () -> Void) {
        onPreview = preview
        onChange = changed
        entries = startingLanguages()
        if panel == nil {
            buildPanel()
        }
        reloadRows()
        guard let panel else { return }
        if panel.parent == nil, let parent {
            parent.addChildWindow(panel, ordered: .above)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private func buildPanel() {
        let width: CGFloat = 560
        let height: CGFloat = 460
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Languages"
        panel.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        panel.contentView = content

        let intro = NSTextField(wrappingLabelWithString: "Change any language. Edit the name, edit the flag, remove a row, or add one. Dutch, English, and Spanish are only a starting list. Once you change this list, those three are no longer built in. A row keeps the Superwhisper mode it started from. A new row matches a mode with the same name.")
        intro.font = NSFont.systemFont(ofSize: 12)
        intro.textColor = .secondaryLabelColor
        intro.preferredMaxLayoutWidth = width - 32
        intro.frame = NSRect(x: 16, y: height - 86, width: width - 32, height: 70)
        content.addSubview(intro)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 52, width: width, height: height - 148))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        content.addSubview(scroll)
        self.scroll = scroll

        let add = NSButton(title: "Add language", target: self, action: #selector(addLanguage))
        add.bezelStyle = .rounded
        add.frame = NSRect(x: 16, y: 12, width: 140, height: 32)
        content.addSubview(add)

        panel.center()
        self.panel = panel
    }

    private func reloadRows() {
        guard let scroll else { return }
        let header: CGFloat = 24
        let count = max(entries.count, 1)
        let documentHeight = header + CGFloat(count) * rowHeight + 8
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: documentHeight))
        wordFields = []
        flagFields = []

        let nameHeader = NSTextField(labelWithString: "Language")
        nameHeader.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        nameHeader.textColor = .secondaryLabelColor
        nameHeader.frame = NSRect(x: 16, y: documentHeight - 20, width: 220, height: 16)
        document.addSubview(nameHeader)
        let flagHeader = NSTextField(labelWithString: "Flag")
        flagHeader.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        flagHeader.textColor = .secondaryLabelColor
        flagHeader.frame = NSRect(x: 248, y: documentHeight - 20, width: 80, height: 16)
        document.addSubview(flagHeader)

        if entries.isEmpty {
            let empty = NSTextField(labelWithString: "No languages yet. Add one, or dictation shows the mode name.")
            empty.textColor = .secondaryLabelColor
            empty.frame = NSRect(x: 16, y: documentHeight - header - 24, width: 500, height: 20)
            document.addSubview(empty)
        }

        var y = documentHeight - header - rowHeight
        for (index, entry) in entries.enumerated() {
            let word = NSTextField(frame: NSRect(x: 16, y: y + 4, width: 220, height: 26))
            word.stringValue = entry.word
            word.placeholderString = "Language"
            word.font = NSFont.systemFont(ofSize: 13)
            word.delegate = self
            document.addSubview(word)
            wordFields.append(word)

            let box = NSComboBox(frame: NSRect(x: 248, y: y + 4, width: 88, height: 26))
            box.addItems(withObjectValues: countryCodes)
            box.completes = true
            box.numberOfVisibleItems = 12
            box.placeholderString = "Flag"
            box.font = NSFont.systemFont(ofSize: 13)
            box.stringValue = entry.flag
            box.delegate = self
            document.addSubview(box)
            flagFields.append(box)

            let preview = NSButton(title: "Preview", target: self, action: #selector(previewRow(_:)))
            preview.tag = index
            preview.bezelStyle = .rounded
            preview.frame = NSRect(x: 346, y: y + 3, width: 84, height: 28)
            document.addSubview(preview)

            let remove = NSButton(title: "Remove", target: self, action: #selector(removeRow(_:)))
            remove.tag = index
            remove.bezelStyle = .rounded
            remove.frame = NSRect(x: 438, y: y + 3, width: 84, height: 28)
            document.addSubview(remove)
            y -= rowHeight
        }
        scroll.documentView = document
        if focusNewRow, let field = wordFields.last {
            focusNewRow = false
            panel?.makeFirstResponder(field)
        }
    }

    @objc func controlTextDidChange(_ obj: Notification) {
        commit(saveEmptyRows: false)
    }

    @objc func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let box = notification.object as? NSComboBox else { return }
        let index = box.indexOfSelectedItem
        if index >= 0, let value = box.objectValueOfSelectedItem as? String {
            box.stringValue = value
        }
        commit(saveEmptyRows: false)
    }

    private func readFields() {
        for index in entries.indices {
            if wordFields.indices.contains(index) {
                entries[index].word = wordFields[index].stringValue
            }
            if flagFields.indices.contains(index) {
                entries[index].flag = flagFields[index].stringValue
            }
        }
    }

    private func commit(saveEmptyRows: Bool) {
        readFields()
        persist(saveEmptyRows: saveEmptyRows)
        onChange?()
    }

    private func persist(saveEmptyRows: Bool) {
        var settings = FlagSettings.load()
        settings.languages = entries.compactMap { entry in
            var copy = entry
            copy.word = copy.word.trimmingCharacters(in: .whitespacesAndNewlines)
            copy.flag = normalizeFlag(copy.flag) ?? ""
            copy.modeKey = copy.modeKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !saveEmptyRows, copy.word.isEmpty, copy.flag.isEmpty, copy.modeKey.isEmpty {
                return nil
            }
            return copy
        }
        settings.flags = [:]
        try? settings.save()
    }

    @objc private func addLanguage() {
        readFields()
        entries.append(LanguageChoice())
        focusNewRow = true
        reloadRows()
    }

    @objc private func removeRow(_ sender: NSButton) {
        readFields()
        guard entries.indices.contains(sender.tag) else { return }
        entries.remove(at: sender.tag)
        reloadRows()
        persist(saveEmptyRows: false)
        onChange?()
    }

    @objc private func previewRow(_ sender: NSButton) {
        readFields()
        guard entries.indices.contains(sender.tag) else { return }
        guard let code = normalizeFlag(entries[sender.tag].flag) else { return }
        persist(saveEmptyRows: false)
        onChange?()
        onPreview?(code)
    }
}

private final class SettingsApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let preview = ScreenPreview(frame: .zero)
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Language Flash"
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 560))
        window.contentView = content

        let subtitle = NSTextField(wrappingLabelWithString: "Size is the percent of the screen width. Opacity is how solid the flag is. Time is how long it stays up. Languages… changes every language, including Dutch, English, and Spanish.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = NSFont.systemFont(ofSize: 13)
        subtitle.preferredMaxLayoutWidth = 480
        place(subtitle, NSRect(x: 20, y: 496, width: 480, height: 52), in: content)

        place(preview, NSRect(x: 20, y: 332, width: 480, height: 152), in: content)

        addSliderRow(
            title: "Size",
            slider: sizeSlider,
            value: sizeValue,
            y: 292,
            in: content
        )
        addSliderRow(
            title: "Opacity",
            slider: opacitySlider,
            value: opacityValue,
            y: 256,
            in: content
        )
        addSliderRow(
            title: "Time",
            slider: timeSlider,
            value: timeValue,
            y: 220,
            in: content
        )

        let previewButton = NSButton(title: "Preview", target: self, action: #selector(previewSample))
        previewButton.bezelStyle = .rounded
        place(previewButton, NSRect(x: 20, y: 172, width: 120, height: 32), in: content)
        let languagesButton = NSButton(title: "Languages…", target: self, action: #selector(showLanguages))
        languagesButton.bezelStyle = .rounded
        place(languagesButton, NSRect(x: 148, y: 172, width: 130, height: 32), in: content)

        loginCheck.font = NSFont.systemFont(ofSize: 13)
        place(loginCheck, NSRect(x: 18, y: 132, width: 280, height: 24), in: content)
        loginSettingsButton.bezelStyle = .rounded
        loginSettingsButton.target = self
        loginSettingsButton.action = #selector(openLoginItems)
        place(loginSettingsButton, NSRect(x: 340, y: 128, width: 160, height: 32), in: content)

        dot.frame = NSRect(x: 20, y: 100, width: 10, height: 10)
        content.addSubview(dot)
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        place(statusLabel, NSRect(x: 38, y: 92, width: 330, height: 22), in: content)
        startButton.bezelStyle = .rounded
        startButton.target = self
        startButton.action = #selector(startOrRestart)
        place(startButton, NSRect(x: 380, y: 86, width: 120, height: 32), in: content)

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
        for slider in [sizeSlider, opacitySlider, timeSlider] {
            slider.target = self
            slider.action = #selector(sliderMoved(_:))
        }
        loginCheck.target = self
        loginCheck.action = #selector(loginChanged(_:))
    }

    private func currentSettings() -> FlagSettings {
        var settings = FlagSettings.load()
        settings.widthPercent = sizeSlider.doubleValue.rounded()
        settings.opacityPercent = opacitySlider.doubleValue.rounded()
        settings.seconds = ((timeSlider.doubleValue / 0.05).rounded() * 0.05 * 100).rounded() / 100
        return settings.clamped()
    }

    private func applyToPreview() {
        let settings = currentSettings()
        preview.sample = sampleFlag(from: settings)
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

    @objc private func sliderMoved(_: NSSlider) {
        applyToPreview()
        scheduleSave()
    }

    @objc private func previewSample() {
        let code = sampleFlag(from: FlagSettings.load())
        guard !code.isEmpty else {
            note.stringValue = "Add a language with a flag first."
            note.textColor = .systemRed
            return
        }
        previewCountry(code)
    }

    @objc private func showLanguages() {
        LanguageEditor.shared.show(relativeTo: window, preview: { [weak self] code in
            self?.previewCountry(code)
        }, changed: { [weak self] in
            self?.applyToPreview()
        })
    }

    private func previewCountry(_ code: String) {
        saveWork?.cancel()
        save()
        guard let executable = agentExecutable() else {
            note.stringValue = "The background flash is not installed, so there is nothing to preview on screen."
            note.textColor = .systemRed
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = ["--preview", code]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            note.stringValue = "Could not preview: \(error.localizedDescription)"
            note.textColor = .systemRed
        }
    }

    private func ensureLoginItem() {
        if #available(macOS 13.0, *), embeddedAgentPlistExists() {
            let service = SMAppService.agent(plistName: agentPlistName)
            if service.status == .notRegistered {
                try? service.register()
            }
        }
        // SMAppService can report success without loading the job. launchctl is what Start uses.
        if !agentProcessStatus().loaded {
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
        let domain = "gui/\(getuid())"
        let service = "\(domain)/\(launchAgentLabel)"
        _ = runCommand("/bin/launchctl", ["enable", service])
        _ = runCommand("/bin/launchctl", ["bootout", service])
        var bootstrap = runCommand("/bin/launchctl", ["bootstrap", domain, plist.path])
        if bootstrap.0 != 0 && !agentProcessStatus().loaded {
            _ = runCommand("/bin/launchctl", ["enable", service])
            _ = runCommand("/bin/launchctl", ["bootout", service])
            bootstrap = runCommand("/bin/launchctl", ["bootstrap", domain, plist.path])
        }
        _ = runCommand("/bin/launchctl", ["kickstart", "-k", service])
        if !agentProcessStatus().loaded {
            let detail = bootstrap.1
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
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
            if service.status == .notRegistered || service.status == .notFound {
                try? service.register()
            }
            if !agentProcessStatus().loaded {
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
        if !agentProcessStatus().loaded {
            installLegacyAgent()
        }
        _ = runCommand("/bin/launchctl", ["enable", service])
        var kick = runCommand("/bin/launchctl", ["kickstart", "-k", service])
        if kick.1.contains("Could not find service") {
            installLegacyAgent()
            kick = runCommand("/bin/launchctl", ["kickstart", "-k", service])
        }
        refreshStatus()
        if !running {
            let detail = (failure ?? kick.1)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
            failure = detail.isEmpty
                ? "Could not start the flash. Turn on “Start when you log in”, then click Start again."
                : "Could not start the flash. \(detail)"
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
