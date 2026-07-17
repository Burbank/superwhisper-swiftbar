import AppKit
import Foundation

let supportDir = NSHomeDirectory() + "/Library/Application Support/superwhisper-swiftbar"
let soundsDir = supportDir + "/sounds"
let fifoPath = soundsDir + "/play.fifo"

func loadSound(_ name: String) -> NSSound? {
    let path = soundsDir + "/" + name
    guard let sound = NSSound(contentsOfFile: path, byReference: false) else {
        fputs("sound-server: failed to load \(path)\n", stderr)
        return nil
    }
    sound.volume = 1.0
    return sound
}

guard
    let us = loadSound("now_US.wav"),
    let nl = loadSound("now_NL.wav"),
    let es = loadSound("now_ES.wav")
else {
    exit(1)
}

let sounds: [String: NSSound] = [
    "default": us,
    "en": us,
    "EN": us,
    "US": us,
    "us": us,

    "super": nl,
    "nl": nl,
    "NL": nl,

    "es": es,
    "ES": es,
    "es-ES": es,
    "es-MX": es,
    "spanish": es,
]

let fm = FileManager.default
try? fm.removeItem(atPath: fifoPath)
if mkfifo(fifoPath, 0o600) != 0 {
    fputs("sound-server: mkfifo failed: \(errno)\n", stderr)
    exit(2)
}

func play(_ key: String) {
    let token = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let sound = sounds[token] else { return }
    if sound.isPlaying { sound.stop() }
    sound.currentTime = 0
    _ = sound.play()
}

DispatchQueue.global(qos: .userInteractive).async {
    while true {
        guard let handle = FileHandle(forReadingAtPath: fifoPath) else {
            usleep(50_000)
            continue
        }
        let data = handle.readDataToEndOfFile()
        try? handle.close()
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { continue }
        for line in text.split(whereSeparator: \.isNewline) {
            let key = String(line)
            DispatchQueue.main.async {
                play(key)
            }
        }
    }
}

fputs("sound-server: ready\n", stderr)
RunLoop.main.run()
