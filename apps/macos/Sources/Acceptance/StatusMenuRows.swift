import AppKit
import Carbon.HIToolbox
import SlackfmtKit

enum StatusMenuDriver {
    enum Opening: String { case rightClick = "a right-click", optionClick = "an Option-left-click" }

    static func open(_ app: App, _ how: Opening) -> [AXUIElement]? {
        guard let frame = StatusItem.frame(app.pid) else { return nil }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        Input.move(to: point)
        switch how {
        case .rightClick: Input.click(point, button: .right)
        case .optionClick: Input.click(point, flags: .maskAlternate)
        }
        for _ in 0..<30 {
            usleep(50_000)
            guard app.windows.contains(where: { $0.isOnScreen && $0.layer == Int(CGWindowLevelForKey(.popUpMenuWindow)) }) else { continue }
            if let menu = StatusItem.element(app.pid).flatMap({ AX.children($0).first }) {
                let items = AX.children(menu)
                if !items.isEmpty { return items }
            }
        }
        return nil
    }

    /// A menu's items as "title" or "---", with each one's state and shortcut.
    static func describe(_ items: [AXUIElement]) -> [String] {
        items.map { item in
            let title = AX.string(item, "AXTitle") ?? ""
            guard !title.isEmpty else { return "---" }
            var text = title
            if AX.attribute(item, "AXEnabled") as? Bool == false { text += " (disabled)" }
            if let key = AX.string(item, "AXMenuItemCmdChar"), !key.isEmpty {
                let modifiers = AX.attribute(item, "AXMenuItemCmdModifiers") as? Int ?? 0
                text += " [" + (modifiers & 4 != 0 ? "⌃" : "") + (modifiers & 2 != 0 ? "⌥" : "") + (modifiers & 1 != 0 ? "⇧" : "") + (modifiers & 8 == 0 ? "⌘" : "") + key + "]"
            }
            if let mark = AX.string(item, "AXMenuItemMarkChar"), !mark.isEmpty { text += " \(mark)" }
            return text
        }
    }

    /// Clicks an item of the open menu; returns the time just before.
    static func choose(_ items: [AXUIElement], _ title: String) -> Double? {
        guard let item = items.first(where: { AX.string($0, "AXTitle") == title }), let frame = AX.frame(item) else { return nil }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        Input.move(to: point)
        return Input.click(point)
    }
}

func rowA10Menu(_ app: App) async {
    let report = Report("A10 the menu")
    let order = ["Copy for Slack", "Hotkey (disabled) [⌃⌥⌘V]", "---", "Launch at login", "---", "Check Slack's format", "---", "Quit Slackfmt [⌘Q]"]
    for how in [StatusMenuDriver.Opening.rightClick, .optionClick] {
        let entries = app.entries.count
        let items = StatusMenuDriver.open(app, how).map(StatusMenuDriver.describe) ?? []
        report.check(items.map { $0.replacingOccurrences(of: " ✓", with: "") } == order, "\(how.rawValue) opens the menu in §6's order", items.joined(separator: " · "))
        Menus.cancel()
        pause(2)
        report.check(app.entries.last?.text == "status idle" && app.entries.count == entries, "\(how.rawValue) doesn't convert")
    }
    func tick() -> Bool? {
        defer { Menus.cancel() }
        return StatusMenuDriver.open(app, .rightClick).map { StatusMenuDriver.describe($0).contains("Launch at login ✓") }
    }
    let first = tick()
    report.note("Launch at login was \(first.map { $0 ? "ticked" : "not ticked" } ?? "unread")")
    for expected in [!(first ?? false), first ?? false] {
        if let items = StatusMenuDriver.open(app, .rightClick) { _ = StatusMenuDriver.choose(items, "Launch at login") }
        usleep(800_000)
        report.check(tick() == expected, "choosing Launch at login flips its tick", expected ? "ticked" : "not ticked")
    }
    report.finish()

    let copy = Report("A10 Copy for Slack in the menu (A1's checks)")
    let before = Clipboard.put(plain: Fixtures.text("fixture.md"))
    usleep(300_000)
    if let items = StatusMenuDriver.open(app, .rightClick), let start = StatusMenuDriver.choose(items, "Copy for Slack") {
        await checkDone(copy, app, start: start, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        copy.check(NSPasteboard.general.changeCount > before, "changeCount moved")
        checkPasteboard(copy, pickle: Fixtures.data("fixture.pickle"), delta: Fixtures.text("fixture.delta.json"))
    } else {
        copy.check(false, "the menu opened")
    }
    copy.finish()
}

func rowA10Quit() {
    let report = Report("A10 quitting")
    for byKey in [false, true] {
        guard let app = App(["-hasRunBefore", "YES"]) else { continue }
        warmTheHarness()
        guard let items = StatusMenuDriver.open(app, .rightClick) else {
            report.check(false, "the menu opened")
            continue
        }
        if byKey { Input.key(kVK_ANSI_Q, flags: .maskCommand) } else { _ = StatusMenuDriver.choose(items, "Quit Slackfmt") }
        let deadline = now() + 3_000
        while now() < deadline, kill(app.pid, 0) == 0 { usleep(50_000) }
        report.check(kill(app.pid, 0) != 0, byKey ? "⌘Q with the menu open ends the process" : "Quit Slackfmt ends the process")
    }
    report.finish()
}

func rowA10Focus(_ app: App) {
    let report = Report("A10 focus, windows and the capsule, F1 to F4 with TextEdit in front")
    let running = NSRunningApplication(processIdentifier: app.pid)
    report.check(running?.activationPolicy == .accessory, "activationPolicy is accessory")
    let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
    let dockItems = dock.flatMap { AX.children(AXUIElementCreateApplication($0.processIdentifier)).first }.map(AX.children) ?? []
    report.check(!dockItems.isEmpty && !dockItems.contains { AX.string($0, "AXTitle") == "Slackfmt" }, "the Dock shows no Slackfmt icon", "\(dockItems.count) Dock items read")

    guard let textEdit = TextEdit.open(Fixtures.text("fixture.md")) else { return report.check(false, "TextEdit opened a document") }
    func isKey() -> Bool {
        let window = AX.element(AXUIElementCreateApplication(textEdit.processIdentifier), "AXFocusedWindow")
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == textEdit.processIdentifier && window != nil
    }
    var seen: Set<String> = []
    func watch(_ seconds: Double) {
        let end = now() + seconds * 1000
        while now() < end {
            for window in app.windows where window.isOnScreen {
                seen.insert("layer \(window.layer), \(Int(window.bounds.width)) x \(Int(window.bounds.height))")
            }
            usleep(10_000)
        }
    }
    func trial(_ name: String, _ fire: () -> Double?) {
        Clipboard.put(plain: Fixtures.text("fixture.md"))
        usleep(300_000)
        guard fire() != nil else { return report.check(false, "\(name) fired") }
        watch(2.2)
        report.check(isKey(), "\(name): TextEdit stays frontmost and key")
    }
    trial("F1 click") { Trigger.click.fire(app) }
    trial("F2 hotkey") { Trigger.hotkey.fire(app) }
    trial("F3 Services") { TextEdit.copyForSlack() }
    report.check(!app.entries.filter { $0.text == "status done" }.isEmpty, "the conversions ran", "\(app.entries.filter { $0.text == "status done" }.count) done")

    var reached: [String] = []
    for shown in [false, true] {
        textEdit.activate()
        pause(1)
        Clipboard.put(plain: Fixtures.text("fixture.md"))
        pause(0.3)
        if shown { _ = Trigger.hotkey.fire(app) }
        pause(0.5)
        let point = app.capsule.map { CGPoint(x: $0.bounds.midX, y: $0.bounds.midY) } ?? CGPoint(x: 864, y: 1027)
        if shown { report.check(app.capsule != nil, "the capsule was up to click", "\(point)") }
        Input.move(to: point)
        Input.click(point)
        pause(0.8)
        reached.append(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")
        pause(1.5)
    }
    report.check(reached[0] == reached[1] && reached[0] != "TextEdit", "a click on the capsule lands on the window beneath", "without the capsule it reaches \(reached[0]), with it \(reached[1])")
    report.note("the app's windows seen on screen: \(seen.sorted().joined(separator: "; "))")
    report.check(seen.allSatisfy { $0.hasSuffix("x 36") || $0.hasPrefix("layer 25") || $0.hasPrefix("layer 24") }, "only R17's windows showed")
    textEdit.activate()
    usleep(500_000)
    TextEdit.close()
    report.finish()
}

/// The banner Notification Center shows, or the app's alert, as text.
func shownMessage(_ app: App, timeout: Double) -> (how: String, text: String)? {
    let deadline = now() + timeout * 1000
    while now() < deadline {
        let windows = AX.attribute(AXUIElementCreateApplication(app.pid), "AXWindows") as? [AXUIElement] ?? []
        if let alert = windows.first {
            let text = allText(alert).joined(separator: " | ")
            if !text.isEmpty { return ("alert", text) }
        }
        if let center = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first {
            let banners = AX.attribute(AXUIElementCreateApplication(center.processIdentifier), "AXWindows") as? [AXUIElement] ?? []
            let text = banners.flatMap(allText).joined(separator: " | ")
            if text.contains("Slackfmt"), text.contains("Slack's format") || text.contains("No Slack format") { return ("notification", text) }
        }
        usleep(100_000)
    }
    return nil
}

func dismissAlert(_ app: App) {
    let windows = AX.attribute(AXUIElementCreateApplication(app.pid), "AXWindows") as? [AXUIElement] ?? []
    guard let button = windows.first.flatMap({ AX.element($0, "AXDefaultButton") }) else { return }
    AX.press(button)
    usleep(500_000)
}

private func allText(_ element: AXUIElement) -> [String] {
    var found: [String] = []
    for name in ["AXValue", "AXTitle", "AXDescription"] {
        if let text = AX.string(element, name), !text.isEmpty { found.append(text) }
    }
    return found + AX.children(element).flatMap(allText)
}

func rowA11(_ app: App, notificationsOn: Bool) {
    let how = notificationsOn ? "notification" : "alert"
    let report = Report("A11 with notifications \(notificationsOn ? "on" : "off")")
    let plain = Data("plain".utf8)
    let cases: [(String, [NSPasteboard.PasteboardType: Data], FormatCheck)] = [
        ("a Slack copy's format", [PasteboardTypes.customData: Pickle.encode([("public.utf8-plain-text", "hi"), ("slack/texty", #"{"ops":[{"insert":"hi\n"}]}"#)]), .string: plain], .matches),
        ("a slack/texty that isn't a Delta", [PasteboardTypes.customData: Pickle.encode([("slack/texty", #"{"blocks":[]}"#)]), .string: plain], .changed),
        ("a pickle with no slack/texty", [PasteboardTypes.customData: Pickle.encode([("text/other", "x")]), .string: plain], .changed),
        ("bytes that don't decode", [PasteboardTypes.customData: Data([1, 2, 3, 4, 5]), .string: plain], .changed),
        ("plain text", [.string: plain], .absent),
    ]
    for (name, contents, expected) in cases {
        Clipboard.put(contents)
        usleep(300_000)
        guard let items = StatusMenuDriver.open(app, .rightClick), StatusMenuDriver.choose(items, "Check Slack's format") != nil else {
            report.check(false, "\(name): the menu opened")
            continue
        }
        let shown = shownMessage(app, timeout: 4)
        report.check(shown?.how == how && shown?.text.contains(expected.message) == true, "\(name): \(how)", shown.map { "\($0.how): \($0.text)" } ?? "nothing shown")
        dismissAlert(app)
        sleep(notificationsOn ? 7 : 1)
    }
    report.finish()
}
