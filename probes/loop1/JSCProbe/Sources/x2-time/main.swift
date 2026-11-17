// X2's loop from a plain executable, so it can be signed the way the app would be: see
// probes/loop1/x2-signed.sh, which runs it with and without com.apple.security.cs.allow-jit.
import Foundation
import ProbeKit

do {
    let input = try Paths.fixture("fixture-20k.md")
    let core = try Core()
    let label = CommandLine.arguments.dropFirst().first ?? "x2-time"
    print("\(label) input fixture-20k.md: \(input.utf16.count) UTF-16 units; bundle loaded once in \(String(format: "%.1f", core.loadMs)) ms (not timed)")
    let timing = try FourTypeTiming.run(core: core, input: input)
    timing.report(label).forEach { print($0) }
    exit(timing.median <= 300 ? 0 : 1)
} catch {
    print("x2-time failed: \(error)")
    exit(2)
}
