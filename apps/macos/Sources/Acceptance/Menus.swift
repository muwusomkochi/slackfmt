import AppKit
import Carbon.HIToolbox

/// Walks a running app's menu bar the way a person does: each menu opens before the next is pressed, since the Services
/// menu is filled only then.
enum Menus {
    static func item(_ app: NSRunningApplication, _ path: [String]) -> AXUIElement? {
        guard let bar = AX.element(AXUIElementCreateApplication(app.processIdentifier), "AXMenuBar") else { return nil }
        var level = AX.children(bar)
        for (index, title) in path.enumerated() {
            guard let found = level.first(where: { AX.string($0, "AXTitle") == title }) else { return nil }
            if index == path.count - 1 { return found }
            AX.press(found)
            usleep(400_000)
            level = AX.children(found).first.map(AX.children) ?? []
        }
        return nil
    }

    static func cancel() {
        Input.key(kVK_Escape, flags: [])
        usleep(100_000)
        Input.key(kVK_Escape, flags: [])
        usleep(200_000)
    }
}

/// A TextEdit document set to plain text, holding `text`, all of it selected, with TextEdit in front.
enum TextEdit {
    static func open(_ text: String) -> NSRunningApplication? {
        let file = NSTemporaryDirectory() + "slackfmt-accept-\(UUID().uuidString).txt"
        try? text.write(toFile: file, atomically: true, encoding: .utf8)
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", "TextEdit", file]
        try? open.run()
        open.waitUntilExit()
        for _ in 0..<60 {
            usleep(100_000)
            if let app = running, app.isActive, window(app, file) != nil { break }
        }
        guard let app = running, app.isActive else { return nil }
        usleep(600_000)
        selectAll()
        return app
    }

    static var running: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first
    }

    static func selectAll() {
        Input.key(kVK_ANSI_A, flags: .maskCommand)
        usleep(300_000)
    }

    /// Closes the front document, which hasn't changed, so nothing asks to save it.
    static func close() {
        guard running?.isActive == true else { return }
        Input.key(kVK_ANSI_W, flags: .maskCommand)
        usleep(300_000)
    }

    private static func window(_ app: NSRunningApplication, _ file: String) -> AXUIElement? {
        let windows = AX.attribute(AXUIElementCreateApplication(app.processIdentifier), "AXWindows") as? [AXUIElement] ?? []
        return windows.first { AX.string($0, "AXTitle")?.contains((file as NSString).lastPathComponent.replacingOccurrences(of: ".txt", with: "")) == true }
    }

    /// Chooses Services > Copy for Slack from TextEdit's menu; returns the time just before it was chosen.
    static func copyForSlack() -> Double? {
        guard let app = running, let item = Menus.item(app, ["TextEdit", "Services", "Copy for Slack"]) else {
            Menus.cancel()
            return nil
        }
        guard let frame = AX.frame(item) else { return nil }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        Input.move(to: point)
        return Input.click(point)
    }
}
