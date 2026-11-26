import AppKit
import SlackfmtKit

func rowA4(_ app: App, _ trigger: Trigger) async {
    func refused(_ name: String, _ reason: String, _ contents: [NSPasteboard.PasteboardType: Data]) async {
        let report = Report("A4 \(name) by \(trigger.rawValue)")
        let before = Clipboard.put(contents)
        pause(0.3)
        guard let start = trigger.fire(app) else { return }
        await checkNothing(report, app, start: start, reason: reason, before: before, glyph: false)
        report.finish()
    }
    let png = NSPasteboard.PasteboardType.png, tiff = NSPasteboard.PasteboardType.tiff
    let image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!.tiffRepresentation!
    let file = Data("file:///Applications/".utf8)

    let empty = Report("A4 a pasteboard with no types by \(trigger.rawValue)")
    NSPasteboard.general.clearContents()
    let before = NSPasteboard.general.changeCount
    pause(0.3)
    if let start = trigger.fire(app) { await checkNothing(empty, app, start: start, reason: "Clipboard is empty", before: before, glyph: false) }
    empty.finish()

    await refused("spaces and newlines only", "Clipboard is empty", [.string: Data(" \n  \n\t ".utf8)])
    await refused("HTML and image types, as Safari's Copy Image writes", "Images can't be converted", [.html: Data("<img src=\"https://example.com/a.png\">".utf8), tiff: image, png: image])
    await refused("an image and a file URL together", "Files can't be converted", [png: image, .fileURL: file])
    await refused("200,001 code units", "Too long to convert", [.string: Data(String(repeating: "a", count: 200_001).utf8)])

    let longest = Report("A4 exactly 200,000 code units by \(trigger.rawValue)")
    let words = String(String(repeating: "plain words\n", count: 20_000).prefix(200_000))
    let count = Clipboard.put(plain: words)
    pause(0.3)
    if let start = trigger.fire(app), let end = Clipboard.waitForChange(after: count, timeout: 30_000) {
        pause(0.3)
        longest.check(Clipboard.slackDelta != nil, "converts", "\(words.utf16.count) code units in \(format(end - start)) ms")
    } else {
        longest.check(false, "converts", "no change within 30 s")
    }
    sleep(2)
    longest.finish()
}

/// Whatever the pasteboard holds now, as one app copied it.
func rowRefusedAsCopied(_ app: App, _ trigger: Trigger, row: String, reason: String, glyph: Bool) async {
    let report = Report("\(row) by \(trigger.rawValue)")
    report.note("types: \((NSPasteboard.general.types ?? []).map(\.rawValue).joined(separator: ", "))")
    let before = NSPasteboard.general.changeCount
    guard let start = trigger.fire(app) else { return }
    await checkNothing(report, app, start: start, reason: reason, before: before, glyph: glyph)
    report.finish()
}

func rowA4Throw(_ app: App, _ trigger: Trigger) async {
    let report = Report("A4 fixture.md with --test-throw by \(trigger.rawValue)")
    let before = Clipboard.put(plain: Fixtures.text("fixture.md"))
    pause(0.3)
    guard let start = trigger.fire(app) else { return }
    await checkNothing(report, app, start: start, reason: "Couldn't convert this", before: before, glyph: false)
    report.finish()
}

func rowA15(_ app: App, _ trigger: Trigger, only: String? = nil) {
    let inputs: [(String, NSPasteboard.PasteboardType, String)] = [
        ("fixture-20k.md", .string, "fixture-20k-md"),
        ("fixture-20k.html", .html, "fixture-20k-html"),
        ("fixture-20k.rtf", .rtf, "fixture-20k-rtf"),
        ("fixture-20k.delta.json", .string, "fixture-20k-delta"),
    ]
    for (name, type, expected) in inputs where only == nil || name == only {
        let report = Report("A15 \(name) by \(trigger.rawValue)")
        let reference = Fixtures.data("expected/\(expected).pickle")
        var times: [Double] = []
        var matches = 0
        for _ in 1...20 {
            let before = Clipboard.put([type: Fixtures.data(name)])
            pause(0.2)
            guard let start = trigger.fire(app), let end = Clipboard.waitForChange(after: before, timeout: 5_000) else { break }
            times.append(end - start)
            pause(0.25)
            if NSPasteboard.general.data(forType: PasteboardTypes.customData) == reference { matches += 1 }
            pause(1.2)
        }
        report.note("runs (ms): \(times.map(format).joined(separator: ", "))")
        report.check(times.count == 20 && median(times) <= 300, "median within 300 ms", times.isEmpty ? "no runs" : "median \(format(median(times))) ms, min \(format(times.min()!)), max \(format(times.max()!))")
        report.check(matches == 20, "every output matches its V23 reference", "\(matches) of 20")
        report.finish()
    }
}

func convertAndCompare(_ report: Report, _ app: App, _ trigger: Trigger, _ what: String, _ contents: [NSPasteboard.PasteboardType: Data], _ expected: String) {
    let before = Clipboard.put(contents)
    pause(0.3)
    guard trigger.fire(app) != nil, Clipboard.waitForChange(after: before, timeout: 5_000) != nil else {
        return report.check(false, what, "nothing was written")
    }
    pause(0.3)
    report.check(sameJSON(Clipboard.slackDelta, Fixtures.text(expected)), what, expected)
    pause(1.2)
}

func rowA17(_ app: App, _ trigger: Trigger) {
    let report = Report("A17 by \(trigger.rawValue)")
    let html = Fixtures.data("fixture.html"), rtf = Fixtures.data("a17.rtf"), plain = Data("plain wins".utf8)
    convertAndCompare(report, app, trigger, "HTML, RTF and plain text", [.html: html, .rtf: rtf, .string: plain], "fixture-html.delta.json")
    convertAndCompare(report, app, trigger, "RTF and plain text", [.rtf: rtf, .string: plain], "expected/a17-rtf.delta.json")
    convertAndCompare(report, app, trigger, "HTML and plain text", [.html: html, .string: plain], "fixture-html.delta.json")
    convertAndCompare(report, app, trigger, "plain text only", [.string: plain], "expected/a17-plain.delta.json")
    report.finish()
}

func rowA18(_ app: App, _ trigger: Trigger) {
    let report = Report("A18 by \(trigger.rawValue)")
    for file in try! FileManager.default.contentsOfDirectory(atPath: Fixtures.folder.appendingPathComponent("a18").path).sorted() {
        let name = file.replacingOccurrences(of: ".txt", with: "")
        convertAndCompare(report, app, trigger, name, [.string: Fixtures.data("a18/\(file)")], "expected/a18-\(name).delta.json")
    }
    report.finish()
}

/// A7's conversions: fixture.md with a canary line, ten by the hotkey. The files it prints are the app's captured output.
func rowA7(_ app: App, canary: String) {
    var converted = 0
    for _ in 1...10 {
        let before = Clipboard.put(plain: "\(canary)\n\n\(Fixtures.text("fixture.md"))")
        pause(0.3)
        guard Trigger.hotkey.fire(app) != nil, Clipboard.waitForChange(after: before, timeout: 5_000) != nil else { continue }
        pause(0.3)
        if Clipboard.slackDelta?.contains(canary) == true { converted += 1 }
        pause(1.2)
    }
    print("\(converted) of 10 conversions carried the canary")
    print("output \(app.log) \(app.errors)")
}

func rowA7Throw(_ app: App, canary: String) {
    let before = Clipboard.put(plain: "\(canary)\n\n\(Fixtures.text("fixture.md"))")
    pause(0.3)
    _ = Trigger.hotkey.fire(app)
    sleep(2)
    print("throw case: changeCount unchanged \(NSPasteboard.general.changeCount == before); \(app.entries.last { $0.text.hasPrefix("status nothing") }?.text ?? "no refusal")")
    print("output \(app.log) \(app.errors)")
}

/// V21's hooks that exit: --convert-now's three codes, and --reset-first-run.
func rowHooks() {
    let report = Report("V21 hooks")
    func exitCode(_ flags: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/Applications/Slackfmt.app/Contents/MacOS/Slackfmt")
        process.arguments = flags
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
    Clipboard.put(plain: Fixtures.text("fixture.md"))
    report.check(exitCode(["--convert-now"]) == 0, "--convert-now exits 0 when it converts")
    report.check(sameJSON(Clipboard.slackDelta, Fixtures.text("fixture.delta.json")), "and the Delta is fixture.md's")
    let converted = NSPasteboard.general.changeCount
    report.check(exitCode(["--convert-now"]) == 2, "exits 2 on Slack's format")
    report.check(NSPasteboard.general.changeCount == converted, "and leaves the clipboard")
    Clipboard.put(plain: "made-up words")
    report.check(exitCode(["--convert-now", "--test-throw"]) == 1, "exits 1 with --test-throw")
    report.check(NSPasteboard.general.string(forType: .string) == "made-up words", "and leaves the clipboard")
    report.finish()
}
