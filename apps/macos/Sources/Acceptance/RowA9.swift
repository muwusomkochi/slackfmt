import AppKit
import SlackfmtKit

func rowA9(_ app: App) async {
    let report = Report("A9, F3 from TextEdit")
    guard let textEdit = TextEdit.open(Fixtures.text("fixture.md")) else { return report.check(false, "TextEdit opened the document") }
    let before = Clipboard.put(plain: "not the selection")
    lastFrame = StatusItem.frame(app.pid)
    _ = app.capsuleNumber
    guard let start = servicesCall(report, app) else { return }
    await checkDone(report, app, start: start, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    report.check(NSPasteboard.general.changeCount > before, "changeCount moved")
    checkPasteboard(report, pickle: Fixtures.data("fixture.pickle"), delta: Fixtures.text("fixture.delta.json"))
    report.check(NSWorkspace.shared.frontmostApplication?.processIdentifier == textEdit.processIdentifier, "TextEdit is still frontmost")
    report.finish()
    rowA2("A9's Services conversion")
    TextEdit.close()
}

func rowA9Refused(_ app: App, _ name: String, _ text: String, _ reason: String) async {
    let report = Report("A9 \(name), from TextEdit")
    guard TextEdit.open(text) != nil else { return report.check(false, "TextEdit opened the document") }
    let before = Clipboard.put(plain: "not the selection")
    guard let start = servicesCall(report, app) else { return }
    await checkNothing(report, app, start: start, reason: reason, before: before, glyph: false)
    report.finish()
    TextEdit.close()
}

/// Chooses the service from TextEdit's menu; returns when macOS called the app, and notes how long the menu took to close.
private func servicesCall(_ report: Report, _ app: App) -> Double? {
    guard let chosen = TextEdit.copyForSlack() else {
        TextEdit.close()
        report.check(false, "Services > Copy for Slack is in TextEdit's menu")
        return nil
    }
    guard let call = app.servicesCall(after: chosen) else {
        TextEdit.close()
        report.check(false, "macOS called the service")
        return nil
    }
    report.note("menu close, from the choice to the Services call: \(format(call - chosen)) ms")
    return call
}

func rowA15Services(_ app: App) {
    let report = Report("A15 fixture-20k.md by Services")
    guard TextEdit.open(Fixtures.text("fixture-20k.md")) != nil else { return report.check(false, "TextEdit opened the document") }
    let reference = Fixtures.data("expected/fixture-20k-md.pickle")
    var times: [Double] = []
    var closes: [Double] = []
    var matches = 0
    for _ in 1...20 {
        let before = Clipboard.put(plain: "not the selection")
        guard let chosen = TextEdit.copyForSlack(), let end = Clipboard.waitForChange(after: before, timeout: 5_000),
              let call = app.servicesCall(after: chosen) else { break }
        times.append(end - call)
        closes.append(call - chosen)
        pause(0.3)
        if NSPasteboard.general.data(forType: PasteboardTypes.customData) == reference { matches += 1 }
        pause(1.2)
    }
    report.note("runs, Services call to changeCount (ms): \(times.map(format).joined(separator: ", "))")
    report.note("menu close before each call (ms): \(closes.map(format).joined(separator: ", "))")
    report.check(times.count == 20 && median(times) <= 300, "median within 300 ms of the call", times.isEmpty ? "no runs" : "median \(format(median(times))) ms, min \(format(times.min()!)), max \(format(times.max()!))")
    report.check(matches == 20, "every output matches its V23 reference", "\(matches) of 20")
    report.finish()
    TextEdit.close()
}

/// The same conversion by NSPerformService: the Services call itself, without the time TextEdit's menu takes to close.
func rowServicesCall(_ app: App) {
    let report = Report("A9 and A15 supplement: the Services call itself (NSPerformService), without TextEdit's menu")
    NSApplication.shared.setActivationPolicy(.accessory)
    for (name, runs) in [("fixture.md", 5), ("fixture-20k.md", 20)] {
        let reference = Fixtures.data(name == "fixture.md" ? "fixture.pickle" : "expected/fixture-20k-md.pickle")
        var times: [Double] = []
        var done: [Double] = []
        var matches = 0
        for _ in 1...runs {
            let board = NSPasteboard.withUniqueName()
            board.clearContents()
            board.setString(Fixtures.text(name), forType: .string)
            let before = Clipboard.put(plain: "not the selection")
            pause(0.25)
            let start = now()
            DispatchQueue.global().async { NSPerformService("Copy for Slack", board) }
            guard let end = Clipboard.waitForChange(after: before, timeout: 5_000) else { break }
            times.append(end - start)
            pause(1.5)
            if NSPasteboard.general.data(forType: PasteboardTypes.customData) == reference { matches += 1 }
            if let entry = app.entries.first(where: { $0.time >= start && $0.text == "status done" }) { done.append(entry.time - start) }
            board.releaseGlobally()
        }
        report.note("\(name) runs, call to changeCount (ms): \(times.map(format).joined(separator: ", "))")
        report.note("\(name) done shown after the call (ms): \(done.map(format).joined(separator: ", "))")
        report.check(times.count == runs && median(times) <= 300, "\(name) median within 300 ms of the call", times.isEmpty ? "no runs" : "median \(format(median(times))) ms, max \(format(times.max()!))")
        report.check(matches == runs, "\(name) every output matches its reference", "\(matches) of \(runs)")
    }
    report.finish()
}
