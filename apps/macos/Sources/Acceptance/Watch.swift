import AppKit
import SlackfmtKit

/// Waits for him to copy something, then for the Mac to be still, so a row can run on his own copy.
func waitForCopy(_ what: String, hours: Double, _ matches: () -> Bool) -> Bool {
    let deadline = now() + hours * 3_600_000
    var seen = NSPasteboard.general.changeCount
    print("waiting for \(what)")
    while now() < deadline {
        pause(0.5)
        guard NSPasteboard.general.changeCount != seen else { continue }
        seen = NSPasteboard.general.changeCount
        guard matches() else { continue }
        while Input.idle < 2 { pause(0.2) }
        return NSPasteboard.general.changeCount == seen
    }
    return false
}

/// A3, and A11's first case, on his own Slack desktop copy.
func rowA3(hours: Double) async {
    guard let app = App(["-hasRunBefore", "YES"]) else { return print("the app didn't launch") }
    warmTheHarness()
    guard waitForCopy("a Slack copy", hours: hours, { Clipboard.slackDelta != nil }) else { return print("no Slack copy came") }
    await checkSlackCopy(app)
}

/// The same on the Slack copy already on the clipboard, which the rows leave as it is.
func rowA3Now() async {
    guard let app = App(["-hasRunBefore", "YES"]) else { return print("the app didn't launch") }
    warmTheHarness()
    await checkSlackCopy(app)
}

private func checkSlackCopy(_ app: App) async {
    let pointer = Input.pointer
    for trigger in [Trigger.click, .hotkey] {
        await rowRefusedAsCopied(app, trigger, row: "A3 a Slack desktop copy", reason: "Already Slack format", glyph: true)
    }
    let report = Report("A11 a Slack desktop copy")
    report.note("slack/texty: \(Clipboard.slackDelta.map { "\($0.utf16.count) UTF-16 units" } ?? "none")")
    if let items = StatusMenuDriver.open(app, .rightClick), StatusMenuDriver.choose(items, "Check Slack's format") != nil {
        let shown = shownMessage(app, timeout: 4)
        report.check(shown?.text.contains(FormatCheck.matches.message) == true, "its own format still matches", shown.map { "\($0.how): \($0.text)" } ?? "nothing shown")
        dismissAlert(app)
    } else {
        report.check(false, "the menu opened")
    }
    report.finish()
    Input.move(to: pointer)
}

/// A4's Safari case, on his own Copy Image.
func rowA4Safari(hours: Double) async {
    guard let app = App(["-hasRunBefore", "YES"]) else { return print("the app didn't launch") }
    warmTheHarness()
    let images: Set<NSPasteboard.PasteboardType> = PasteboardTypes.images
    guard waitForCopy("an image copied in Safari", hours: hours, {
        let types = NSPasteboard.general.types ?? []
        return !images.isDisjoint(with: types) && !types.contains { $0.rawValue.hasPrefix("org.chromium") }
    }) else { return print("no image came") }
    let pointer = Input.pointer
    for trigger in [Trigger.click, .hotkey] {
        await rowRefusedAsCopied(app, trigger, row: "A4 an image copied from Safari", reason: "Images can't be converted", glyph: false)
    }
    Input.move(to: pointer)
}

/// A1 with Reduce Motion, once he has turned it on.
func rowA1ReduceMotion(hours: Double) async {
    let deadline = now() + hours * 3_600_000
    print("waiting for Reduce Motion")
    while !reduceMotionIsOn() {
        guard now() < deadline else { return print("Reduce Motion stayed off") }
        pause(0.5)
    }
    print("Reduce Motion is on")
    while Input.idle < 3 { pause(0.2) }
    let snapshot = ClipboardSnapshot()
    let pointer = Input.pointer
    guard let app = App(["-hasRunBefore", "YES"]) else { return print("the app didn't launch") }
    warmTheHarness()
    for trigger in [Trigger.click, .hotkey] { await rowA1(app, trigger, reduceMotion: true) }
    Input.move(to: pointer)
    snapshot.restore()
    print("Reduce Motion \(reduceMotionIsOn() ? "was still on" : "had been turned off") when the runs ended")
}

/// The setting as it stands, read by a process of its own: NSWorkspace's copy never changes in one with no NSApplication running.
func reduceMotionIsOn() -> Bool {
    output("/usr/bin/osascript", ["-l", "JavaScript", "-e", "ObjC.import('AppKit'); $.NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion"])
        .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
}

/// A16: each state's announcement, by click, once he has VoiceOver on. He listens; a picture of VoiceOver's caption panel is kept.
func rowA16(hours: Double, folder: String, from first: Int = 1) async {
    func voiceOverIsOn() -> Bool {
        output("/usr/bin/osascript", ["-l", "JavaScript", "-e", "ObjC.import('AppKit'); $.NSWorkspace.sharedWorkspace.voiceOverEnabled"])
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
    let deadline = now() + hours * 3_600_000
    print("waiting for VoiceOver")
    while !voiceOverIsOn() {
        guard now() < deadline else { return print("VoiceOver stayed off") }
        pause(0.5)
    }
    print("VoiceOver is on")
    print("waiting for 20 s of stillness")
    while Input.idle < 20 { pause(0.2) }
    let snapshot = ClipboardSnapshot()
    let image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!.tiffRepresentation!
    let file = Data("file:///Applications/".utf8)
    let text: (String) -> [NSPasteboard.PasteboardType: Data] = { [.string: Data($0.utf8)] }
    let cases: [(String, [NSPasteboard.PasteboardType: Data]?)] = [
        ("A1 fixture.md", text(Fixtures.text("fixture.md"))),
        ("A3 Slack's format", nil),
        ("A4 no types", [:]),
        ("A4 spaces and newlines", text(" \n \n")),
        ("A4 an image", [.png: image]),
        ("A4 a file, as Finder copies one", [.fileURL: file, .tiff: image, .string: Data("a name".utf8)]),
        ("A4 a file URL alone", [.fileURL: file]),
        ("A4 an image as Safari copies one", [.tiff: image, .html: Data("<img src=x>".utf8)]),
        ("A4 an image and a file URL", [.png: image, .fileURL: file]),
        ("A4 200,000 code units", text(String(String(repeating: "plain words\n", count: 20_000).prefix(200_000)))),
        ("A4 200,001 code units", text(String(repeating: "a", count: 200_001))),
    ]
    func run(_ app: App, _ index: Int, _ name: String, _ contents: [NSPasteboard.PasteboardType: Data]?) {
        if let contents {
            if contents.isEmpty { NSPasteboard.general.clearContents() } else { Clipboard.put(contents) }
        }
        pause(0.6)
        // By click, as A16 says (F1 stands for F2 and F3): the hotkey holds VoiceOver's own keys, and VoiceOver takes it.
        guard let start = Trigger.click.fire(app) else { return print("\(index). \(name): not run, the status item wasn't on screen") }
        var shots = 0
        while now() - start < 4_500 {
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
            for window in windows where (window[kCGWindowOwnerName as String] as? String) == "VoiceOver" {
                guard let bounds = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary), bounds.width < 1_000,
                      let number = window[kCGWindowNumber as String] as? Int else { continue }
                shots += 1
                _ = output("/usr/sbin/screencapture", ["-x", "-o", "-l\(number)", "\(folder)/\(index)-\(shots).png"])
            }
            pause(0.3)
        }
        print("\(index). \(name): VoiceOver \(voiceOverIsOn() ? "on" : "off"); \(app.entries.filter { $0.time >= start && $0.text.hasPrefix("status") }.map(\.text).first ?? "no state")")
        pause(1)
    }
    guard let app = App(["-hasRunBefore", "YES"]) else { return print("the app didn't launch") }
    warmTheHarness()
    pause(4)
    for (index, item) in cases.enumerated() where index + 1 >= first { run(app, index + 1, item.0, item.1) }
    guard let throwing = App(["-hasRunBefore", "YES", "--test-throw"]) else { return print("the app didn't launch") }
    pause(6)
    run(throwing, cases.count + 1, "A4 fixture.md with --test-throw", text(Fixtures.text("fixture.md")))
    _ = App(["-hasRunBefore", "YES"])
    snapshot.restore()
    print("finished")
}
