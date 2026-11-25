import AppKit
import SlackfmtKit


/// Watches the capsule's window for `seconds` after `start`.
func watchCapsule(_ app: App, start: Double, seconds: Double) -> [(time: Double, window: App.Window?)] {
    var samples: [(Double, App.Window?)] = []
    while now() - start < seconds * 1000 {
        samples.append((now() - start, app.capsule))
        usleep(4_000)
    }
    return samples
}

func checkDone(_ report: Report, _ app: App, start: Double, reduceMotion: Bool) async {
    async let glyph = Task.detached { () -> CGImage? in
        let wait = 100 - (now() - start)
        if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1e6)) }
        guard let frame = lastFrame else { return nil }
        return await Glyph.capture(frame)
    }.value
    let samples = await Task.detached { watchCapsule(app, start: start, seconds: 2.0) }.value
    let image = await glyph

    let during = stride(from: 100.0, through: 750.0, by: 10).map { app.status(at: start + $0) ?? "none" }
    report.check(Set(during) == ["done"], "state log: done from +0.1 s through +0.75 s", Set(during).sorted().joined(separator: ", "))
    report.check(app.status(at: start + 1300) == "idle", "state log: idle by +1.3 s", app.status(at: start + 1300) ?? "none")
    let moments = app.entries.filter { $0.time >= start }.map { "\($0.text) +\(format($0.time - start))" }
    report.note("state log (ms after the trigger): \(moments.joined(separator: "; "))")

    if let image {
        let scores = Glyph.scores(image)
        report.check(scores[0].name == "checkmark" && scores[0].score > 0.6, "screenshot at +0.1 s shows V16's checkmark", scores.map { "\($0.name) \(String(format: "%.2f", $0.score))" }.joined(separator: ", "))
    } else {
        report.check(false, "screenshot at +0.1 s", "no image")
    }

    let at200 = samples.first { $0.time >= 200 }?.window
    let at1600 = samples.first { $0.time >= 1600 }?.window
    report.check(at200 != nil, "capsule shows at +0.2 s")
    report.check(at1600 == nil, "capsule is gone at +1.6 s")
    if let window = at200 {
        let screens = NSScreen.screens
        let top = screens[0].frame.maxY
        let screen = screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? screens[0]
        let bottom = top - window.bounds.maxY
        report.check(window.bounds.height == 36, "capsule is 36 pt high", "\(window.bounds.height)")
        report.check(abs(window.bounds.midX - screen.frame.midX) <= 0.5, "capsule is centred on the pointer's screen", "\(window.bounds.midX) on a screen centred at \(screen.frame.midX)")
        report.check(abs(bottom - screen.visibleFrame.minY - 72) <= 0.5, "capsule's bottom edge is 72 pt above the visible frame's bottom", "\(bottom - screen.visibleFrame.minY)")
    }
    if let last = samples.last(where: { $0.window != nil }) {
        report.note("capsule last on screen at +\(format(last.time)) ms")
    }
    let alphas = samples.compactMap(\.window).map(\.alpha)
    let between = alphas.filter { $0 > 0.02 && $0 < 0.98 }
    if reduceMotion {
        report.check(between.isEmpty && !alphas.isEmpty, "Reduce Motion: alpha has no value between 0 and 1", "\(alphas.count) samples, between: \(between.map { String(format: "%.2f", $0) })")
    } else {
        report.note("fades: \(between.count) of \(alphas.count) capsule samples between 0 and 1")
    }
    report.note("screens attached: \(NSScreen.screens.count)")
}

func checkNothing(_ report: Report, _ app: App, start: Double, reason: String, before: Int, glyph: Bool) async {
    async let image = Task.detached { () -> CGImage? in
        guard glyph else { return nil }
        let wait = 100 - (now() - start)
        if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1e6)) }
        guard let frame = lastFrame else { return nil }
        return await Glyph.capture(frame)
    }.value
    let shot = await image
    while now() - start < 400 { usleep(5_000) }
    let tip = StatusItem.element(app.pid).flatMap { AX.string($0, "AXHelp") }
    while now() - start < 2_000 { usleep(5_000) }

    let during = Set(stride(from: 100.0, through: 1250.0, by: 10).map { app.status(at: start + $0) ?? "none" })
    report.check(during == ["nothing \(reason)"], "state log: nothing (\"\(reason)\") from +0.1 s through +1.25 s", during.sorted().joined(separator: ", "))
    report.check(app.status(at: start + 1800) == "idle", "state log: idle by +1.8 s", app.status(at: start + 1800) ?? "none")
    report.check(tip == reason, "tooltip", tip ?? "none")
    report.check(NSPasteboard.general.changeCount == before, "changeCount unchanged", "\(before) -> \(NSPasteboard.general.changeCount)")
    report.check(app.capsule == nil && !app.entries.contains { $0.time >= start && $0.text == "capsule shown" }, "no capsule")
    if glyph {
        let scores = shot.map(Glyph.scores)
        report.check(scores?[0].name == "nosign" && (scores?[0].score ?? 0) > 0.6, "screenshot at +0.1 s shows V16's nosign", scores?.map { "\($0.name) \(String(format: "%.2f", $0.score))" }.joined(separator: ", ") ?? "no image")
    }
}

func checkPasteboard(_ report: Report, pickle: Data, delta: String) {
    report.check(NSPasteboard.general.data(forType: PasteboardTypes.customData) == pickle, "pickle bytes equal the reference", "\(pickle.count) bytes")
    report.check(sameJSON(Clipboard.slackDelta, delta), "decoded slack/texty deep-equals the reference")
}

func rowA1(_ app: App, _ trigger: Trigger, reduceMotion: Bool = false) async {
    let report = Report("A1 by \(trigger.rawValue)\(reduceMotion ? " with Reduce Motion" : "")")
    let before = Clipboard.put(plain: Fixtures.text("fixture.md"))
    usleep(300_000)
    _ = app.capsuleNumber
    guard let start = trigger.fire(app) else { return }
    await checkDone(report, app, start: start, reduceMotion: reduceMotion)
    report.check(NSPasteboard.general.changeCount > before, "changeCount moved")
    checkPasteboard(report, pickle: Fixtures.data("fixture.pickle"), delta: Fixtures.text("fixture.delta.json"))
    report.finish()
}
