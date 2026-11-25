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
    guard waitForCopy("an image copied in Safari", hours: hours, { !images.isDisjoint(with: NSPasteboard.general.types ?? []) }) else { return print("no image came") }
    let pointer = Input.pointer
    for trigger in [Trigger.click, .hotkey] {
        await rowRefusedAsCopied(app, trigger, row: "A4 an image copied from Safari", reason: "Images can't be converted", glyph: false)
    }
    Input.move(to: pointer)
}
