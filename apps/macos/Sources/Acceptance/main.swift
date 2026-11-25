import AppKit
import Carbon.HIToolbox
import SlackfmtKit

setvbuf(stdout, nil, _IOLBF, 0)
let arguments = Array(CommandLine.arguments.dropFirst())

func runningApp() -> pid_t {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.anoraq.slackfmt").first else {
        print("Slackfmt isn't running")
        exit(2)
    }
    return app.processIdentifier
}

/// Times conversions of a file by click: plain text onto the general pasteboard, a posted click on the status item,
/// and the time from posting it to the changeCount moving.
func timeClicks(_ path: String, runs: Int) {
    let pid = runningApp()
    let input = try! String(contentsOfFile: path, encoding: .utf8)
    print("input \(URL(fileURLWithPath: path).lastPathComponent): \(input.utf16.count) UTF-16 units; pid \(pid)")
    let snapshot = ClipboardSnapshot()
    let pointer = Input.pointer
    var times: [Double] = []
    for run in 1...runs {
        guard let frame = StatusItem.frame(pid) else {
            print("run \(run): no status item frame")
            break
        }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        Input.move(to: point)
        let before = Clipboard.put(plain: input)
        usleep(150_000)
        let start = Input.click(point)
        guard let end = Clipboard.waitForChange(after: before, timeout: 5_000) else {
            print("run \(run): no change within 5 s; frame \(frame)")
            break
        }
        times.append(end - start)
        usleep(150_000)
        if Clipboard.slackDelta == nil { print("run \(run): no Slack format on the pasteboard") }
        usleep(1_300_000)
    }
    Input.move(to: pointer)
    snapshot.restore()
    print("runs (ms): \(times.map(format).joined(separator: ", "))")
    if times.count == runs {
        print("median of \(runs): \(format(median(times))) ms, min \(format(times.min()!)) ms, max \(format(times.max()!)) ms")
    }
    print("his clipboard put back: \(NSPasteboard.general.types?.count ?? 0) types")
}

/// X9: Slack's own quoted-list form (X4's copied shape, made-up text). The plain text says so if Slack reads it instead.
func writeX9() {
    let delta = #"{"ops":[{"insert":"Packing for the lake"},{"insert":"\n","attributes":{"blockquote":true}},{"insert":"Blue kayak"},{"insert":"\n","attributes":{"list":"bullet","border":1}},{"insert":"Two paddles"},{"insert":"\n","attributes":{"list":"bullet","border":1}}]}"#
    let before = NSPasteboard.general.changeCount
    let after = Clipboard.put([
        PasteboardTypes.customData: Pickle.encode([(PasteboardTypes.slackEntry, delta)]),
        .string: Data("X9: Slack read the plain text, not the pickle".utf8),
    ])
    print("x9-write: changeCount \(before) -> \(after)")
    print("slack/texty read back: \(Clipboard.slackDelta ?? "none")")
}

func isX9OnTheClipboard() -> Bool { Clipboard.slackDelta?.contains("Packing for the lake") == true }

/// Runs a row with his clipboard and pointer put back after, once he's left the Mac alone for a few seconds.
func withHisMac(_ body: () async -> Void) async {
    let deadline = now() + 240_000
    while Input.idle < 8 {
        if now() > deadline { return print("he's using the Mac, so nothing ran") }
        usleep(500_000)
    }
    let snapshot = ClipboardSnapshot()
    let pointer = Input.pointer
    let stopped = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
    signal(SIGTERM, SIG_IGN)
    stopped.setEventHandler {
        snapshot.restore()
        exit(143)
    }
    stopped.activate()
    await body()
    Input.move(to: pointer)
    snapshot.restore()
}

let trigger: Trigger = arguments.contains("--hotkey") ? .hotkey : .click

/// Launches the app (its first run already claimed, so it asks for nothing) and runs a row against it.
func withApp(_ flags: [String] = [], _ body: (App) async -> Void) async {
    await withHisMac {
        guard let app = App(["-hasRunBefore", "YES"] + flags) else { return print("the app didn't launch") }
        warmTheHarness()
        await body(app)
    }
}

switch arguments.first {
case "a1": await withApp { await rowA1($0, trigger); rowA2("A1 by \(trigger.rawValue)") }
case "a4": await withApp { await rowA4($0, trigger) }
case "a4-apps": await withApp { await rowA4Apps($0, trigger, only: arguments[1]) }
case "a4-throw": await withApp(["--test-throw"]) { await rowA4Throw($0, trigger) }
case "a15": await withApp { rowA15($0, trigger, only: arguments.dropFirst().first { $0.hasPrefix("fixture") }) }
case "a17": await withApp { rowA17($0, trigger) }
case "a18": await withApp { rowA18($0, trigger) }
case "a9":
    await withApp { app in
        await rowA9(app)
        await rowA9Refused(app, "200,001 code units selected", String(repeating: "plain words\n", count: 16_667).prefix(200_001).description, "Too long to convert")
    }
case "a9-throw": await withApp(["--test-throw"]) { await rowA9Refused($0, "fixture.md with --test-throw", Fixtures.text("fixture.md"), "Couldn't convert this") }
case "glyph-probe":
    await withApp { app in
        for (name, text) in [("nothing", "  "), ("done", "made-up words")] {
            Clipboard.put(plain: text)
            pause(0.4)
            guard let start = trigger.fire(app), let frame = lastFrame else { return }
            while now() - start < 100 { usleep(1_000) }
            if let image = await Glyph.capture(frame) {
                Glyph.save(image, "\(arguments[1])/\(name).png")
                print("\(name): \(Glyph.scores(image).map { "\($0.name) \(String(format: "%.2f", $0.score))" }.joined(separator: ", "))")
            }
            pause(2.2)
        }
        if let frame = StatusItem.frame(app.pid), let image = await Glyph.capture(frame) {
            Glyph.save(image, "\(arguments[1])/idle.png")
            print("idle: \(Glyph.scores(image).map { "\($0.name) \(String(format: "%.2f", $0.score))" }.joined(separator: ", "))")
        }
    }
case "press-probe":
    await withApp { app in
        // VoiceOver presses with its own keys held: Control and Option.
        for (name, flags) in [("a press", CGEventFlags([])), ("a press with Control and Option held", CGEventFlags([.maskControl, .maskAlternate]))] {
            Clipboard.put(plain: "made-up words")
            pause(0.4)
            let codes = flags.isEmpty ? [] : [kVK_Control, kVK_Option]
            for code in codes { CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: true)?.post(tap: .cghidEventTap) }
            pause(0.2)
            let start = now()
            if let item = StatusItem.element(app.pid) { AX.press(item) }
            pause(1.8)
            for code in codes { CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: false)?.post(tap: .cghidEventTap) }
            print("\(name): \(app.entries.filter { $0.time >= start }.map { "\($0.text) +\(format($0.time - start))" }.joined(separator: "; "))")
            Menus.cancel()
        }
    }
case "notify-probe":
    await withApp { app in
        Clipboard.put(plain: "plain")
        pause(0.4)
        guard let items = StatusMenuDriver.open(app, .rightClick), StatusMenuDriver.choose(items, "Check Slack's format") != nil else { return print("no menu") }
        let start = now()
        while now() - start < 8_000 {
            pause(0.25)
            let center = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first
            let windows = center.map { AX.attribute(AXUIElementCreateApplication($0.processIdentifier), "AXWindows") as? [AXUIElement] ?? [] } ?? []
            let mine = AX.attribute(AXUIElementCreateApplication(app.pid), "AXWindows") as? [AXUIElement] ?? []
            if !windows.isEmpty || !mine.isEmpty { print("+\(format(now() - start)): center windows \(windows.count) \(windows.map { AX.string($0, "AXTitle") ?? "?" }), app windows \(mine.count)") }
        }
    }
case "vo-probe":
    func voiceOverIsOn() -> Bool {
        output("/usr/bin/osascript", ["-l", "JavaScript", "-e", "ObjC.import('AppKit'); $.NSWorkspace.sharedWorkspace.voiceOverEnabled"])
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }
    print("waiting for VoiceOver")
    while !voiceOverIsOn() { pause(0.5) }
    print("VoiceOver is on; waiting for 15 s of stillness")
    while Input.idle < 15 { pause(0.2) }
    let held = ClipboardSnapshot()
    for how in arguments[2].split(separator: ",").map(String.init) {
        for later in ["YES"] {
            guard voiceOverIsOn(), let app = App(["-hasRunBefore", "YES", "-announceFrom", how, "-announceLater", later]) else { continue }
            warmTheHarness()
            pause(5)
            Clipboard.put(plain: "made-up words")
            pause(1)
            guard let start = Trigger.hotkey.fire(app) else { continue }
            var shots = 0
            while now() - start < 4_000 {
                let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
                for window in windows where (window[kCGWindowOwnerName as String] as? String) == "VoiceOver" {
                    guard let bounds = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary), bounds.width < 1_000,
                          let number = window[kCGWindowNumber as String] as? Int else { continue }
                    shots += 1
                    _ = output("/usr/sbin/screencapture", ["-x", "-o", "-l\(number)", "\(arguments[1])/\(how)-\(later)-\(shots).png"])
                }
                pause(0.3)
            }
            print("\(how) later=\(later): \(app.entries.filter { $0.time >= start && $0.text.hasPrefix("status done") }.map { "done +" + format($0.time - start) }.first ?? "no state"); caption pictures \(shots)")
        }
    }
    held.restore()
    print("finished")
case "menu-probe":
    await withApp { app in
        Clipboard.put(plain: "made-up words")
        for how in [StatusMenuDriver.Opening.rightClick, .optionClick, .optionClick, .rightClick] {
            let start = now()
            let opened = StatusMenuDriver.open(app, how) != nil
            pause(0.5)
            Menus.cancel()
            pause(2.5)
            print("\(how.rawValue): opened \(opened); \(app.entries.filter { $0.time >= start }.map { "\($0.text) +\(format($0.time - start))" }.joined(separator: "; "))")
        }
    }
case "capsule-probe":
    await withApp { app in
        guard TextEdit.open("made-up words\n") != nil else { return print("no document") }
        for shown in [false, true] {
            TextEdit.running?.activate()
            pause(1)
            Clipboard.put(plain: "made-up words")
            pause(0.3)
            if shown {
                _ = Trigger.hotkey.fire(app)
                pause(0.5)
                print("capsule up: \(app.capsule?.bounds ?? .zero)")
            }
            let point = CGPoint(x: 864, y: 1027)
            let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
            Input.move(to: point)
            Input.click(point)
            pause(0.8)
            print("capsule \(shown ? "shown" : "not shown"): front before \(front), after \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
            pause(1.5)
        }
        TextEdit.running?.activate()
        pause(0.8)
        TextEdit.close()
    }
case "a10-menu": await withApp { await rowA10Menu($0) }
case "a10-focus": await withApp { rowA10Focus($0) }
case "a10-quit": await withHisMac { rowA10Quit() }
case "a11-on": await withApp { rowA11($0, notificationsOn: true) }
case "a11-off": await withApp { rowA11($0, notificationsOn: false) }
case "a3": await rowA3(hours: 6)
case "a3-now":
    if Clipboard.slackDelta != nil { await rowA3Now() } else { print("no Slack copy on the clipboard") }
case "a1-reduce-motion": await rowA1ReduceMotion(hours: 8)
case "a16": await rowA16(hours: 8, folder: arguments[1], from: arguments.count > 2 ? Int(arguments[2])! : 1)
case "a4-safari": await rowA4Safari(hours: 6)
case "a4-copied": await withApp { await rowRefusedAsCopied($0, trigger, row: "A4 \(arguments[1])", reason: arguments[2], glyph: false) }
case "a5": await withApp { rowA5($0) }
case "a5-signing": rowA5Signing()
case "hooks": await withHisMac { rowHooks() }
case "a7": await withApp { rowA7($0, canary: arguments[1]) }
case "a7-throw": await withApp(["--test-throw"]) { rowA7Throw($0, canary: arguments[1]) }
case "services-call": await withApp { rowServicesCall($0) }
case "services-latency":
    await withApp { app in
        for run in 1...Int(arguments[1])! {
            guard TextEdit.open("made-up words \(run)\n") != nil else { return print("no document") }
            let before = Clipboard.put(plain: "not the selection")
            guard let start = TextEdit.copyForSlack() else { return print("no Services item") }
            let pressed = now()
            let end = Clipboard.waitForChange(after: before, timeout: 5_000)
            usleep(1_800_000)
            let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
            let moments = app.entries.filter { $0.time >= start }.map { "\($0.text) +\(format($0.time - start))" }
            print("run \(run): press returned +\(format(pressed - start)); change +\(end.map { format($0 - start) } ?? "none"); front after: \(front); \(moments.joined(separator: "; "))")
            if let app = TextEdit.running { app.activate() }
            usleep(500_000)
            TextEdit.close()
        }
    }
case "a15-services": await withApp { rowA15Services($0) }
case "latency":
    await withApp { app in
        for run in 1...Int(arguments[1])! {
            Clipboard.put(plain: Fixtures.text("fixture.md"))
            usleep(300_000)
            guard let start = trigger.fire(app) else { return }
            usleep(1_800_000)
            let moments = app.entries.filter { $0.time >= start }.map { "\($0.text) +\(format($0.time - start))" }
            print("run \(run): posted \(Input.posted.map { "+" + format($0 - start) }); \(moments.joined(separator: "; "))")
        }
    }
case "x9-write":
    writeX9()
case "x9-check":
    print("changeCount \(NSPasteboard.general.changeCount); X9's pickle still on the clipboard: \(isX9OnTheClipboard())")
case "time-clicks":
    timeClicks(arguments[1], runs: Int(arguments[2])!)
case "toggle-voiceover":
    Input.key(kVK_F5, flags: [.maskCommand, .maskSecondaryFn])
case "idle":
    print(format(Input.idle))
default:
    print("usage: slackfmt-accept a1|a4|a4-throw|a15|a17|a18|latency <runs> [--hotkey] | time-clicks <file> <runs> | x9-write | x9-check | idle")
    exit(64)
}
