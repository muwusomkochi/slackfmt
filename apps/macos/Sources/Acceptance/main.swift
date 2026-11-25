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
    let deadline = now() + 120_000
    while Input.idle < 4, now() < deadline { usleep(500_000) }
    let snapshot = ClipboardSnapshot()
    let pointer = Input.pointer
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
case "a4-throw": await withApp(["--test-throw"]) { await rowA4Throw($0, trigger) }
case "a15": await withApp { rowA15($0, trigger) }
case "a17": await withApp { rowA17($0, trigger) }
case "a18": await withApp { rowA18($0, trigger) }
case "latency":
    await withApp { app in
        for run in 1...Int(arguments[1])! {
            Clipboard.put(plain: Fixtures.text("fixture.md"))
            usleep(300_000)
            guard let start = trigger.fire(app) else { return }
            usleep(1_800_000)
            let moments = app.entries.filter { $0.time >= start }.map { "\($0.text) +\(format($0.time - start))" }
            print("run \(run): \(moments.joined(separator: "; "))")
        }
    }
case "x9-write":
    writeX9()
case "x9-check":
    print("changeCount \(NSPasteboard.general.changeCount); X9's pickle still on the clipboard: \(isX9OnTheClipboard())")
case "time-clicks":
    timeClicks(arguments[1], runs: Int(arguments[2])!)
case "idle":
    print(format(Input.idle))
default:
    print("usage: slackfmt-accept a1|a4|a4-throw|a15|a17|a18|latency <runs> [--hotkey] | time-clicks <file> <runs> | x9-write | x9-check | idle")
    exit(64)
}
