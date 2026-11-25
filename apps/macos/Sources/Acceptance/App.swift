import AppKit

/// The installed app, launched through LaunchServices with V21's state log on standard output.
final class App {
    static let bundleIdentifier = "com.anoraq.slackfmt"
    let pid: pid_t
    let log: String
    let errors: String

    init?(_ flags: [String] = []) {
        App.quit()
        let folder = NSTemporaryDirectory() + "slackfmt-accept"
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        log = "\(folder)/\(UUID().uuidString).out"
        errors = "\(folder)/\(UUID().uuidString).err"
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-n", "-g", "--stdout", log, "--stderr", errors, "/Applications/Slackfmt.app", "--args"] + flags + ["--state-log"]
        try? open.run()
        open.waitUntilExit()
        let deadline = now() + 10_000
        while now() < deadline {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: App.bundleIdentifier).first {
                pid = app.processIdentifier
                sleep(3)
                return
            }
            usleep(50_000)
        }
        return nil
    }

    static func quit() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
            kill(app.processIdentifier, SIGTERM)
        }
        let deadline = now() + 5_000
        while now() < deadline, !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty { usleep(50_000) }
    }

    struct Entry {
        let time: Double
        let text: String
    }

    var entries: [Entry] {
        ((try? String(contentsOfFile: log, encoding: .utf8)) ?? "").split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let time = Double(parts[0]) else { return nil }
            return Entry(time: time, text: String(parts[1]))
        }
    }

    func status(at time: Double) -> String? {
        entries.last { $0.time <= time && $0.text.hasPrefix("status ") }.map { String($0.text.dropFirst("status ".count)) }
    }

    struct Window {
        let layer: Int
        let bounds: CGRect
        let alpha: Double
        let isOnScreen: Bool
    }

    var windows: [Window] {
        let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.filter { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid }.map { window in
            Window(
                layer: window[kCGWindowLayer as String] as? Int ?? 0,
                bounds: CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary) ?? .zero,
                alpha: window[kCGWindowAlpha as String] as? Double ?? 0,
                isOnScreen: window[kCGWindowIsOnscreen as String] as? Bool ?? false)
        }
    }

    /// The capsule's window, found once: it exists off screen from launch, and asking for one window by number costs the
    /// window server little enough not to slow the click being timed.
    private(set) lazy var capsuleNumber: CGWindowID? = {
        let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.first { window in
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  let bounds = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary) else { return false }
            return bounds.height == 36 && bounds.width > 60
        }?[kCGWindowNumber as String] as? CGWindowID
    }()

    var capsule: Window? {
        guard let capsuleNumber else { return nil }
        var numbers: [UnsafeRawPointer?] = [UnsafeRawPointer(bitPattern: UInt(capsuleNumber))]
        guard let array = CFArrayCreate(nil, &numbers, 1, nil),
              let window = (CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]])?.first,
              window[kCGWindowIsOnscreen as String] as? Bool == true else { return nil }
        return Window(
            layer: window[kCGWindowLayer as String] as? Int ?? 0,
            bounds: CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary) ?? .zero,
            alpha: window[kCGWindowAlpha as String] as? Double ?? 0,
            isOnScreen: true)
    }
}
