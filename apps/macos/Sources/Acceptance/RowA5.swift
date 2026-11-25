import AppKit
import Carbon.HIToolbox
import SlackfmtKit

/// A5's run: F1 to F4 ten times with nettop on the app throughout, and lsof for an internet socket after each.
func rowA5(_ app: App) {
    let report = Report("A5 no socket in F1 to F4, ten times")
    let log = NSTemporaryDirectory() + "slackfmt-accept/nettop-\(UUID().uuidString).csv"
    FileManager.default.createFile(atPath: log, contents: nil)
    let nettop = Process()
    nettop.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
    nettop.arguments = ["-p", "\(app.pid)", "-L", "0", "-s", "1", "-x", "-n"]
    nettop.standardOutput = FileHandle(forWritingAtPath: log)
    try? nettop.run()
    usleep(1_500_000)

    guard let textEdit = TextEdit.open(Fixtures.text("fixture.md")) else { return report.check(false, "TextEdit opened a document") }
    var ran = [0, 0, 0, 0]
    var sockets: [String] = []
    func changed(_ body: () -> Double?) -> Bool {
        let before = Clipboard.put(plain: Fixtures.text("fixture.md"))
        usleep(250_000)
        guard body() != nil, Clipboard.waitForChange(after: before, timeout: 5_000) != nil else { return false }
        usleep(1_300_000)
        return true
    }
    for _ in 1...10 {
        if changed({ Trigger.click.fire(app) }) { ran[0] += 1 }
        if changed({ Trigger.hotkey.fire(app) }) { ran[1] += 1 }
        textEdit.activate()
        usleep(300_000)
        if changed({ TextEdit.copyForSlack() }) { ran[2] += 1 }
        if let items = StatusMenuDriver.open(app, .rightClick), StatusMenuDriver.choose(items, "Check Slack's format") != nil {
            if let shown = shownMessage(app, timeout: 4) {
                ran[3] += 1
                if shown.how == "alert" { Input.key(kVK_Return, flags: []) }
            }
            usleep(800_000)
        }
        sockets += output("/usr/sbin/lsof", ["-nP", "-a", "-i", "-p", "\(app.pid)"]).split(separator: "\n").map(String.init).filter { !$0.hasPrefix("COMMAND") }
    }
    nettop.terminate()
    textEdit.activate()
    usleep(300_000)
    TextEdit.close()
    report.check(ran == [10, 10, 10, 10], "F1, F2, F3 and F4 ran ten times each", "\(ran)")
    report.check(sockets.isEmpty, "lsof shows no internet socket", sockets.joined(separator: "; "))
    let lines = ((try? String(contentsOfFile: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    let flows = lines.filter { !$0.hasPrefix("time,") && !$0.contains("Slackfmt.\(app.pid),") && !$0.isEmpty }
    let traffic = lines.filter { $0.contains("Slackfmt.\(app.pid),") }
    report.check(flows.isEmpty, "nettop shows no connection", "\(lines.count) lines read, \(traffic.count) naming the app; flows: \(flows.prefix(3))")
    report.finish()
}

func output(_ path: String, _ arguments: [String]) -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    process.standardOutput = pipe
    process.standardError = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

func rowA5Signing() {
    let report = Report("A5 signing and Info.plist (V12)")
    let app = "/Applications/Slackfmt.app"
    let entitlements = output("/usr/bin/codesign", ["-d", "--entitlements", "-", app])
    report.check(entitlements.contains("com.apple.security.app-sandbox"), "App Sandbox on")
    report.check(entitlements.contains("com.apple.security.cs.allow-jit"), "com.apple.security.cs.allow-jit")
    report.check(!entitlements.contains("com.apple.security.network.client"), "no network client entitlement")
    let keys = entitlements.split(separator: "\n").filter { $0.contains("[Key]") }.map { $0.trimmingCharacters(in: .whitespaces) }
    report.check(keys.count == 2, "those two entitlements and no other", keys.joined(separator: ", "))
    let signature = output("/usr/bin/codesign", ["-dvv", app])
    report.check(signature.contains("(runtime)"), "hardened runtime flag", signature.split(separator: "\n").first { $0.contains("flags=") }.map(String.init) ?? "")
    report.check(signature.contains("Authority=Apple Development"), "an Apple Development authority")
    report.check(output("/usr/bin/lipo", ["-archs", app + "/Contents/MacOS/Slackfmt"]).trimmingCharacters(in: .whitespacesAndNewlines) == "arm64", "arm64")
    let info = NSDictionary(contentsOfFile: app + "/Contents/Info.plist") ?? [:]
    for (key, value) in [("CFBundleIdentifier", "com.anoraq.slackfmt"), ("CFBundleExecutable", "Slackfmt"), ("LSMinimumSystemVersion", "14.0")] {
        report.check(info[key] as? String == value, "\(key) is \(value)", "\(info[key] ?? "none")")
    }
    report.finish()
}
