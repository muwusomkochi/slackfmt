import Foundation

/// V21's `--state-log`: each status item state, the capsule's shown and hidden moments, macOS's Services calls (R4's
/// trigger for F3) and the menu's Copy for Slack action calls (R4's trigger for R35), on standard output, with a monotonic
/// time in ms. Never clipboard content.
enum StateLog {
    static let isOn = CommandLine.arguments.contains("--state-log")

    static func write(_ line: String) {
        guard isOn else { return }
        let milliseconds = Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e6
        print(String(format: "%.1f", milliseconds), line)
        fflush(stdout)
    }
}
