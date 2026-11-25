import AppKit
import SlackfmtKit

setvbuf(stdout, nil, _IOLBF, 0)
let arguments = Array(CommandLine.arguments.dropFirst())

func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

func format(_ value: Double) -> String { String(format: "%.1f", value) }

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

switch arguments.first {
case "time-clicks":
    timeClicks(arguments[1], runs: Int(arguments[2])!)
case "idle":
    print(format(Input.idle))
default:
    print("usage: slackfmt-accept time-clicks <file> <runs> | idle")
    exit(64)
}
