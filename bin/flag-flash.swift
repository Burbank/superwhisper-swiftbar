// flag-flash.swift — flash the active Superwhisper language when the dictation key is pressed.
// Project: README.md#language-flag-flash
//
// Listen-only event tap, so Superwhisper still receives the shortcut.
// The flag comes from activeModeKey and the mode's language. This app does not
// track whether a recording is already running.

import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import QuartzCore

private let preferenceDomain = "com.superduper.superwhisper" as CFString
private let samePressWindow: TimeInterval = 0.2
private let launchAgentLabel = "com.burbank.superwhisper-flag-flash"

private struct FlagSettings: Codable {
    var widthPercent: Double = 10
    var opacityPercent: Double = 50
    var seconds: Double = 0.3

    var fadeIn: TimeInterval { min(0.04, seconds * 0.13) }
    var fadeOut: TimeInterval { fadeIn }
    var hold: TimeInterval { max(0, seconds - fadeIn - fadeOut) }
    var widthFraction: CGFloat { CGFloat(widthPercent / 100) }
    var opacity: CGFloat { CGFloat(opacityPercent / 100) }

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

    func summary() -> String {
        let file = settingsFileURL().path
        return """
        width    \(format(widthPercent))% of the screen
        opacity  \(format(opacityPercent))%
        shown    \(format(seconds)) seconds
        file     \(file)
        """
    }
}

private func settingsFileURL() -> URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/superwhisper-swiftbar/flag-flash-settings.json")
}

private func format(_ value: Double) -> String {
    if value == value.rounded() {
        return String(Int(value))
    }
    return String(format: "%.2f", value)
}

private func isDictationShortcutName(_ key: String) -> Bool {
    let lowered = key.lowercased()
    if lowered.contains("cancel") || lowered.contains("changemode") || lowered.contains("change_mode") {
        return false
    }
    return lowered.contains("togglerecording")
        || lowered.contains("pushtotalk")
        || lowered.contains("push_to_talk")
        || lowered.contains("startrecording")
}

private let cmdKeyBit = 256
private let shiftKeyBit = 512
private let optionKeyBit = 2048
private let controlKeyBit = 4096
private let rightShiftKeyBit = 8192
private let rightOptionKeyBit = 16384
private let rightControlKeyBit = 32768

private let modifierKeyCodes: Set<Int> = [54, 55, 56, 58, 59, 60, 61, 62, 63]
private let relevantFlags: CGEventFlags = [
    .maskCommand, .maskShift, .maskAlternate, .maskControl, .maskSecondaryFn,
]

private func log(_ message: String) {
    fputs("flag-flash: \(message)\n", stderr)
    fflush(stderr)
}

// MARK: - Flags

private enum FlagKind {
    case netherlands
    case unitedStates
    case spain
    case label(String)

    var aspect: CGFloat {
        switch self {
        case .netherlands, .spain: return 1.5
        case .unitedStates: return 1.9
        case .label: return 2.4
        }
    }
}

private func flagKind(language: String, key: String, name: String) -> FlagKind {
    let lang = language.split(separator: "-").first.map { String($0).lowercased() } ?? ""
    let token = lang.isEmpty ? key.lowercased() : lang
    switch token {
    case "nl", "nld", "dutch", "super":
        return .netherlands
    case "en", "eng", "english", "us", "usa", "default":
        return .unitedStates
    case "es", "spa", "spanish":
        return .spain
    default:
        let title = name.isEmpty ? key : name
        return .label(title.isEmpty ? "?" : title)
    }
}

private func previewKind(_ token: String) -> FlagKind? {
    switch token.lowercased() {
    case "nl", "nld", "dutch", "super":
        return .netherlands
    case "en", "eng", "english", "us", "usa", "default":
        return .unitedStates
    case "es", "spa", "spanish":
        return .spain
    default:
        return nil
    }
}

private enum FlagDrawing {
    static func draw(_ kind: FlagKind, in rect: NSRect) {
        switch kind {
        case .netherlands:
            stripes([
                (nsColor(0xAE1C28), 1),
                (NSColor.white, 1),
                (nsColor(0x21468B), 1),
            ], in: rect)
        case .spain:
            stripes([
                (nsColor(0xAA151B), 1),
                (nsColor(0xF1BF00), 2),
                (nsColor(0xAA151B), 1),
            ], in: rect)
        case .unitedStates:
            unitedStates(in: rect)
        case .label(let text):
            label(text, in: rect)
        }
    }

    private static func stripes(_ bands: [(NSColor, CGFloat)], in rect: NSRect) {
        let total = bands.reduce(CGFloat(0)) { $0 + $1.1 }
        var y = rect.maxY
        for (color, weight) in bands {
            let height = rect.height * weight / total
            y -= height
            color.setFill()
            NSRect(x: rect.minX, y: y, width: rect.width, height: height).fill()
        }
    }

    private static func unitedStates(in rect: NSRect) {
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
                let x: CGFloat
                if count == 6 {
                    x = canton.minX + (CGFloat(column) + 0.5) * columnWidth
                } else {
                    x = canton.minX + (CGFloat(column) + 1) * columnWidth
                }
                star(center: CGPoint(x: x, y: y), radius: radius).fill()
            }
        }
    }

    private static func star(center: CGPoint, radius: CGFloat) -> NSBezierPath {
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

    private static func label(_ text: String, in rect: NSRect) {
        nsColor(0x14161C).setFill()
        NSBezierPath(
            roundedRect: rect,
            xRadius: rect.height * 0.08,
            yRadius: rect.height * 0.08
        ).fill()

        var size = rect.height * 0.34
        var font = NSFont.systemFont(ofSize: size, weight: .bold)
        let maxWidth = rect.width * 0.88
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        if textWidth > maxWidth, textWidth > 0 {
            size *= maxWidth / textWidth
            font = NSFont.systemFont(ofSize: max(size, 24), weight: .bold)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let bounds = string.boundingRect(
            with: NSSize(width: maxWidth, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textRect = NSRect(
            x: rect.midX - maxWidth / 2,
            y: rect.midY - bounds.height / 2,
            width: maxWidth,
            height: bounds.height
        )
        string.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    private static func nsColor(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private final class FlagView: NSView {
    var kind: FlagKind {
        didSet { needsDisplay = true }
    }

    init(kind: FlagKind) {
        self.kind = kind
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func draw(_ dirtyRect: NSRect) {
        FlagDrawing.draw(kind, in: bounds)
    }
}

private final class FlashWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class Overlay {
    private var windows: [FlashWindow] = []
    private var hideWork: DispatchWorkItem?
    private var generation = 0

    func flash(_ kind: FlagKind) {
        generation += 1
        let token = generation
        hideWork?.cancel()

        let screens = NSScreen.screens
        if screens.isEmpty {
            log("no displays")
            return
        }
        let settings = FlagSettings.load()
        let fadeIn = settings.fadeIn
        let hold = settings.hold
        let fadeOut = settings.fadeOut
        windows.forEach { $0.orderOut(nil) }
        windows = screens.map { _ in makeWindow() }

        for (window, screen) in zip(windows, screens) {
            let width = screen.frame.width * settings.widthFraction
            var height = width / kind.aspect
            let maxHeight = screen.frame.height * 0.7
            var fittedWidth = width
            if height > maxHeight {
                height = maxHeight
                fittedWidth = height * kind.aspect
            }
            if let view = window.contentView as? FlagView {
                view.kind = kind
            }
            window.setFrame(
                NSRect(
                    x: screen.frame.midX - fittedWidth / 2,
                    y: screen.frame.midY - height / 2,
                    width: fittedWidth,
                    height: height
                ),
                display: false
            )
            window.contentView?.needsDisplay = true
            window.alphaValue = 0
            window.isMovable = false
            window.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeIn
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in windows {
                window.animator().alphaValue = settings.opacity
            }
        }

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = fadeOut
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                for window in self.windows {
                    window.animator().alphaValue = 0
                }
            }, completionHandler: { [weak self] in
                guard let self, self.generation == token else { return }
                for window in self.windows {
                    window.orderOut(nil)
                }
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeIn + hold, execute: work)
    }

    private func makeWindow() -> FlashWindow {
        let window = FlashWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isExcludedFromWindowsMenu = true
        window.contentView = FlagView(kind: .label(""))
        return window
    }
}

// MARK: - Current mode

private struct Mode: Equatable {
    var key: String
    var name: String
    var language: String
}

private func preferenceValue(_ key: String) -> Any? {
    CFPreferencesAppSynchronize(preferenceDomain)
    return CFPreferencesCopyAppValue(key as CFString, preferenceDomain)
}

private func preferenceString(_ key: String) -> String? {
    guard let value = preferenceValue(key) else { return nil }
    if let string = value as? String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    return nil
}

private func superwhisperFolder() -> URL? {
    let home = FileManager.default.homeDirectoryForCurrentUser
    var candidates: [URL] = []
    if let parent = preferenceString("appFolderDirectory") {
        let parentURL = URL(fileURLWithPath: (parent as NSString).expandingTildeInPath)
        candidates.append(parentURL.appendingPathComponent("superwhisper"))
        candidates.append(parentURL)
    }
    candidates.append(home.appendingPathComponent("superwhisper"))
    candidates.append(home.appendingPathComponent("Documents/superwhisper"))

    for candidate in candidates {
        var isDirectory: ObjCBool = false
        let modes = candidate.appendingPathComponent("modes")
        if FileManager.default.fileExists(atPath: modes.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return candidate
        }
    }
    return nil
}

private func loadModes(in folder: URL) -> [Mode] {
    let directory = folder.appendingPathComponent("modes")
    guard let files = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ) else {
        return []
    }
    var modes: [Mode] = []
    for file in files where file.pathExtension.lowercased() == "json" {
        guard
            let data = try? Data(contentsOf: file),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            continue
        }
        let filename = file.deletingPathExtension().lastPathComponent
        let key = (object["key"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? filename
        let name = (object["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? key
        let language = object["language"] as? String ?? ""
        modes.append(Mode(key: key, name: name, language: language))
    }
    return modes
}

private func currentFlagKind() -> FlagKind {
    guard let activeKey = preferenceString("activeModeKey") else {
        log("could not read activeModeKey")
        return .label("No mode")
    }
    guard let folder = superwhisperFolder() else {
        log("modes folder not found")
        return .label(activeKey)
    }
    let modes = loadModes(in: folder)
    let mode = modes.first { $0.key == activeKey }
        ?? Mode(key: activeKey, name: activeKey, language: "")
    let kind = flagKind(language: mode.language, key: mode.key, name: mode.name)
    log("mode \(mode.key) language \(mode.language.isEmpty ? "(empty)" : mode.language)")
    return kind
}

// MARK: - Dictation shortcut

private struct DictationShortcut: Equatable {
    var name: String
    var keyCode: Int
    var flags: CGEventFlags
    var mode: Mode?

    var signature: String { "\(keyCode)-\(flags.rawValue)" }

    var description: String {
        var parts: [String] = []
        if flags.contains(.maskControl) { parts.append("ctrl") }
        if flags.contains(.maskAlternate) { parts.append("option") }
        if flags.contains(.maskShift) { parts.append("shift") }
        if flags.contains(.maskCommand) { parts.append("command") }
        if flags.contains(.maskSecondaryFn) { parts.append("fn") }
        parts.append("key \(keyCode)")
        let chord = parts.joined(separator: "+")
        if let mode {
            return "\(name) \(chord) (\(mode.key))"
        }
        return "\(name) \(chord)"
    }
}

private func impliedFlags(for keyCode: Int) -> CGEventFlags {
    switch keyCode {
    case 54, 55: return .maskCommand
    case 56, 60: return .maskShift
    case 58, 61: return .maskAlternate
    case 59, 62: return .maskControl
    case 63: return .maskSecondaryFn
    default: return []
    }
}

private func carbonFlags(_ carbon: Int) -> CGEventFlags {
    var flags: CGEventFlags = []
    if carbon & cmdKeyBit != 0 { flags.insert(.maskCommand) }
    if carbon & (shiftKeyBit | rightShiftKeyBit) != 0 { flags.insert(.maskShift) }
    if carbon & (optionKeyBit | rightOptionKeyBit) != 0 { flags.insert(.maskAlternate) }
    if carbon & (controlKeyBit | rightControlKeyBit) != 0 { flags.insert(.maskControl) }
    return flags
}

private func intValue(_ value: Any?) -> Int? {
    switch value {
    case let number as Int:
        return number
    case let number as NSNumber:
        return number.intValue
    default:
        return nil
    }
}

private func shortcutPair(from object: [String: Any]) -> (Int, Int)? {
    if let code = intValue(object["carbonKeyCode"]), let modifiers = intValue(object["carbonModifiers"]) {
        return (code, modifiers)
    }
    if let nested = object["key"] as? [String: Any] {
        return shortcutPair(from: nested)
    }
    return nil
}

private func parseShortcut(named name: String, value: Any) -> DictationShortcut? {
    let pair: (Int, Int)?
    if let object = value as? [String: Any] {
        pair = shortcutPair(from: object)
    } else if let data = value as? Data {
        pair = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap(shortcutPair)
    } else if let string = value as? String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            pair = shortcutPair(from: object)
        } else {
            let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, let code = Int(parts[0]), let modifiers = Int(parts[1]) {
                pair = (code, modifiers)
            } else {
                pair = nil
            }
        }
    } else {
        pair = nil
    }

    guard let (keyCode, modifiers) = pair else {
        return nil
    }
    // A mouse-only binding stores a key code that Superwhisper does not use as a key.
    // carbonKeyCode is still required by KeyboardShortcuts; skip a binding with no key
    // and no modifiers only when the code is negative.
    if keyCode < 0 {
        return nil
    }
    return DictationShortcut(name: name, keyCode: keyCode, flags: carbonFlags(modifiers), mode: nil)
}

private var lastShortcutProblem = ""

private func noteShortcutProblem(_ message: String) {
    guard message != lastShortcutProblem else { return }
    lastShortcutProblem = message
    if !message.isEmpty {
        log(message)
    }
}

private func readShortcuts() -> [DictationShortcut] {
    CFPreferencesAppSynchronize(preferenceDomain)
    guard let keys = CFPreferencesCopyKeyList(
        preferenceDomain,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    ) as? [String] else {
        noteShortcutProblem("could not read Superwhisper preferences")
        return []
    }

    var shortcuts: [DictationShortcut] = []
    var seen: Set<String> = []
    var problems: [String] = []
    for key in keys where isDictationShortcutName(key) {
        guard let value = CFPreferencesCopyAppValue(key as CFString, preferenceDomain) else { continue }
        guard let shortcut = parseShortcut(named: key, value: value) else {
            problems.append("\(key)=\(value)")
            continue
        }
        if seen.insert(shortcut.signature).inserted {
            shortcuts.append(shortcut)
        }
    }
    if problems.isEmpty {
        noteShortcutProblem("")
    } else {
        noteShortcutProblem("could not parse dictation shortcut: \(problems.joined(separator: "; "))")
    }
    return shortcuts
}

private func shortcutKeysForLog() -> [String] {
    CFPreferencesAppSynchronize(preferenceDomain)
    guard let keys = CFPreferencesCopyKeyList(
        preferenceDomain,
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    ) as? [String] else {
        return []
    }
    return keys.filter { key in
        let lowered = key.lowercased()
        return lowered.contains("shortcut") || lowered.contains("record") || lowered.contains("pushtotalk")
    }.sorted()
}

private func matches(_ shortcut: DictationShortcut, keyCode: Int, eventFlags: CGEventFlags) -> Bool {
    guard shortcut.keyCode == keyCode else { return false }
    var present = eventFlags.intersection(relevantFlags)
    // External keyboards often add Fn. Ignore it unless the shortcut is the Fn key itself.
    if keyCode != 63 {
        present.remove(.maskSecondaryFn)
    }
    var allowed = shortcut.flags.union(impliedFlags(for: keyCode))
    if keyCode != 63 {
        allowed.remove(.maskSecondaryFn)
    }
    return present == allowed
}

private func collectCarbonPairs(in value: Any, into pairs: inout [(Int, Int)]) {
    if let object = value as? [String: Any] {
        if let code = intValue(object["carbonKeyCode"]), let modifiers = intValue(object["carbonModifiers"]), code >= 0 {
            pairs.append((code, modifiers))
        }
        for child in object.values {
            collectCarbonPairs(in: child, into: &pairs)
        }
    } else if let array = value as? [Any] {
        for child in array {
            collectCarbonPairs(in: child, into: &pairs)
        }
    }
}

private func readModeShortcuts() -> [DictationShortcut] {
    guard let folder = superwhisperFolder() else { return [] }
    let directory = folder.appendingPathComponent("modes")
    guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
        return []
    }
    var shortcuts: [DictationShortcut] = []
    var seen: Set<String> = []
    for file in files where file.pathExtension.lowercased() == "json" {
        guard
            let data = try? Data(contentsOf: file),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            continue
        }
        let filename = file.deletingPathExtension().lastPathComponent
        let key = (object["key"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? filename
        let name = (object["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? key
        let language = object["language"] as? String ?? ""
        let mode = Mode(key: key, name: name, language: language)
        var pairs: [(Int, Int)] = []
        collectCarbonPairs(in: object, into: &pairs)
        for (keyCode, modifiers) in pairs {
            let shortcut = DictationShortcut(
                name: "mode \(key)",
                keyCode: keyCode,
                flags: carbonFlags(modifiers),
                mode: mode
            )
            if seen.insert(shortcut.signature).inserted {
                shortcuts.append(shortcut)
            }
        }
    }
    return shortcuts
}

private func allDictationShortcuts() -> [DictationShortcut] {
    var bySignature: [String: DictationShortcut] = [:]
    for shortcut in readShortcuts() {
        bySignature[shortcut.signature] = shortcut
    }
    // A per-mode key starts dictation in that mode, so it wins over a global key with the same chord.
    for shortcut in readModeShortcuts() {
        bySignature[shortcut.signature] = shortcut
    }
    return Array(bySignature.values)
}

// MARK: - Event tap

private final class KeyWatcher {
    var onPress: (DictationShortcut) -> Void = { _ in }
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var shortcuts: [DictationShortcut] = []
    private var shortcutsLoadedAt = Date.distantPast
    private var lastFlags: CGEventFlags = []
    private var lastPressAt = Date.distantPast
    private var didPrompt = false
    private var wasTrusted = false
    private var didLogMissingShortcut = false
    private var didLogTapFailure = false

    func start() {
        wasTrusted = AXIsProcessTrusted()
        reloadShortcuts(forceLog: true)
        _ = attachTap()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.maintain()
        }
    }

    func reenableTap() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }

    func receive(type: CGEventType, event: CGEvent) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if type == .flagsChanged {
            let wentDown = modifierWentDown(keyCode: keyCode, previous: lastFlags, current: flags)
            lastFlags = flags
            guard wentDown, modifierKeyCodes.contains(keyCode) else { return }
            if let shortcut = currentShortcuts().first(where: { matches($0, keyCode: keyCode, eventFlags: flags) }) {
                registerPress(shortcut)
            }
            return
        }

        guard type == .keyDown else { return }
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }
        guard let shortcut = currentShortcuts().first(where: { matches($0, keyCode: keyCode, eventFlags: flags) }) else {
            return
        }
        registerPress(shortcut)
    }

    private func registerPress(_ shortcut: DictationShortcut) {
        let now = Date()
        if now.timeIntervalSince(lastPressAt) < samePressWindow { return }
        lastPressAt = now
        DispatchQueue.main.async { [weak self] in
            self?.onPress(shortcut)
        }
    }

    private func modifierWentDown(keyCode: Int, previous: CGEventFlags, current: CGEventFlags) -> Bool {
        let bit = impliedFlags(for: keyCode)
        guard bit.rawValue != 0 else { return false }
        return !previous.contains(bit) && current.contains(bit)
    }

    private func currentShortcuts() -> [DictationShortcut] {
        if Date().timeIntervalSince(shortcutsLoadedAt) > 1 {
            reloadShortcuts(forceLog: false)
        }
        return shortcuts
    }

    private func reloadShortcuts(forceLog: Bool) {
        let fresh = allDictationShortcuts()
        shortcutsLoadedAt = Date()
        let changed = fresh != shortcuts
        shortcuts = fresh
        if fresh.isEmpty {
            if forceLog || changed || !didLogMissingShortcut {
                didLogMissingShortcut = true
                let known = shortcutKeysForLog()
                if known.isEmpty {
                    log("no dictation shortcut found in Superwhisper preferences or mode files")
                } else {
                    log("dictation shortcut not found. Related keys: \(known.joined(separator: ", "))")
                }
            }
        } else if forceLog || changed {
            didLogMissingShortcut = false
            log("listening for \(fresh.map(\.description).joined(separator: ", "))")
        }
    }

    private func maintain() {
        let trusted = AXIsProcessTrusted()
        if trusted && !wasTrusted {
            log("Accessibility granted; restarting so the event tap can attach")
            exit(0)
        }
        wasTrusted = trusted
        reloadShortcuts(forceLog: false)
        if port == nil {
            _ = attachTap()
        } else if let port, !CGEvent.tapIsEnabled(tap: port) {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }

    private func attachTap() -> Bool {
        if port != nil { return true }
        if !AXIsProcessTrusted() && !didPrompt {
            didPrompt = true
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [promptKey: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            log("grant Accessibility to Superwhisper Language Flash. System Settings → Privacy & Security → Accessibility")
        }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let userInfo {
                        Unmanaged<KeyWatcher>.fromOpaque(userInfo).takeUnretainedValue().reenableTap()
                    }
                    return nil
                }
                if let userInfo {
                    let watcher = Unmanaged<KeyWatcher>.fromOpaque(userInfo).takeUnretainedValue()
                    watcher.receive(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            if !didLogTapFailure {
                didLogTapFailure = true
                log("event tap unavailable")
            }
            return false
        }

        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        didLogTapFailure = false
        log("event tap attached")
        return true
    }
}

// MARK: - Recording start

private final class RecordingWatcher {
    var onStart: () -> Void = {}
    private var known: Set<String> = []
    private var source: DispatchSourceFileSystemObject?
    private var recordingsPath: String?
    private var retry: DispatchWorkItem?

    func start() {
        arm()
    }

    private func arm() {
        guard let folder = superwhisperFolder() else {
            log("waiting for the Superwhisper folder")
            retryLater()
            return
        }
        let path = folder.appendingPathComponent("recordings").path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            log("recordings folder not found at \(path)")
            retryLater()
            return
        }
        if path == recordingsPath, source != nil { return }

        source?.cancel()
        let descriptor = Darwin.open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            log("could not watch \(path)")
            retryLater()
            return
        }
        recordingsPath = path
        known = subdirectoryNames(at: path)
        let watched = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .userInteractive)
        )
        watched.setEventHandler { [weak self] in
            self?.scan()
        }
        watched.setCancelHandler {
            Darwin.close(descriptor)
        }
        source = watched
        watched.resume()
        log("watching recordings in \(path)")
    }

    private func subdirectoryNames(at path: String) -> Set<String> {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }
        var directories: Set<String> = []
        for name in names where !name.hasPrefix(".") {
            var isDirectory: ObjCBool = false
            let child = (path as NSString).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: child, isDirectory: &isDirectory), isDirectory.boolValue {
                directories.insert(name)
            }
        }
        return directories
    }

    private func scan() {
        guard let path = recordingsPath else { return }
        let current = subdirectoryNames(at: path)
        let fresh = current.subtracting(known)
        known = current
        guard let name = fresh.sorted().last else { return }
        let child = (path as NSString).appendingPathComponent(name)
        if let created = (try? FileManager.default.attributesOfItem(atPath: child)[.creationDate]) as? Date,
           Date().timeIntervalSince(created) > 8 {
            log("ignored old recording folder \(name)")
            return
        }
        let metaURL = URL(fileURLWithPath: child).appendingPathComponent("meta.json")
        if let data = try? Data(contentsOf: metaURL),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let duration = intValue(object["duration"]),
           duration > 0 {
            log("ignored finished recording \(name)")
            return
        }
        log("recording started \(name)")
        DispatchQueue.main.async { [weak self] in
            self?.onStart()
        }
    }

    private func retryLater() {
        retry?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.arm()
        }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}

// MARK: - App

private final class AppController: NSObject, NSApplicationDelegate {
    let overlay = Overlay()
    let watcher = KeyWatcher()
    let recordingWatcher = RecordingWatcher()
    var preview: FlagKind?
    private var lastLanguageFlash = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let preview {
            let shown = FlagSettings.load().seconds
            DispatchQueue.main.async {
                self.overlay.flash(preview)
                DispatchQueue.main.asyncAfter(deadline: .now() + shown + 0.25) {
                    NSApp.terminate(nil)
                }
            }
            return
        }
        watcher.onPress = { [weak self] shortcut in
            self?.showFlag(for: shortcut)
        }
        recordingWatcher.onStart = { [weak self] in
            self?.showFlag(for: nil)
        }
        watcher.start()
        recordingWatcher.start()
        log("ready")
    }

    private func showFlag(for shortcut: DictationShortcut?) {
        let now = Date()
        if now.timeIntervalSince(lastLanguageFlash) < 1.2 { return }
        lastLanguageFlash = now
        let kind: FlagKind
        if let mode = shortcut?.mode {
            kind = flagKind(language: mode.language, key: mode.key, name: mode.name)
            log("dictation key for mode \(mode.key)")
        } else {
            kind = currentFlagKind()
        }
        overlay.flash(kind)
    }
}

private enum Holder {
    static var controller: AppController?
}

private func handleSettingsCommand() {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let command = arguments.first else { return }
    if command == "settings" || command == "--settings" {
        print(FlagSettings.load().summary())
        exit(0)
    }
    if command == "status" || command == "--status" {
        print(launchAgentStatus())
        print(FlagSettings.load().summary())
        exit(0)
    }
    if command == "set" || command == "--set" {
        guard arguments.count >= 3 else {
            fputs("Usage: flag-flash set width 10 | opacity 50 | seconds 0.3\n", stderr)
            exit(2)
        }
        var settings = FlagSettings.load()
        let name = arguments[1].lowercased()
        let raw = arguments[2].replacingOccurrences(of: "%", with: "")
        guard let value = Double(raw) else {
            fputs("flag-flash: \(arguments[2]) is not a number\n", stderr)
            exit(2)
        }
        switch name {
        case "width", "size":
            settings.widthPercent = value
        case "opacity", "transparency", "alpha":
            settings.opacityPercent = value
        case "seconds", "time", "duration":
            settings.seconds = value
        default:
            fputs("flag-flash: unknown setting \(arguments[1]). Use width, opacity, or seconds.\n", stderr)
            exit(2)
        }
        settings = settings.clamped()
        do {
            try settings.save()
        } catch {
            fputs("flag-flash: could not save settings: \(error)\n", stderr)
            exit(1)
        }
        print(settings.summary())
        exit(0)
    }
}

private func launchAgentStatus() -> String {
    let uid = getuid()
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    task.arguments = ["print", "gui/\(uid)/\(launchAgentLabel)"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        return "Superwhisper Language Flash is not loaded. It starts when you log in."
    }
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    if task.terminationStatus != 0 {
        return "Superwhisper Language Flash is not loaded. It starts when you log in."
    }
    let running = output.contains("state = running")
    let state = running ? "running" : "loaded, not running"
    return """
    Superwhisper Language Flash is \(state).
    It starts again when you log in after a restart. It does not start before the login screen.
    """
}

private func previewArgument() -> FlagKind? {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: "--preview") else { return nil }
    let token = arguments.indices.contains(index + 1) ? arguments[index + 1] : ""
    guard let kind = previewKind(token) else {
        fputs("Usage: flag-flash --preview nl|en|es\n", stderr)
        exit(2)
    }
    return kind
}

handleSettingsCommand()

private let app = NSApplication.shared
private let controller = AppController()
controller.preview = previewArgument()
Holder.controller = controller
app.setActivationPolicy(.accessory)
app.delegate = controller
app.run()
