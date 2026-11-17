import ProbeKit
import XCTest

/// X2 from the Swift test: fixture-20k.md, 20 warm runs, four types written each run.
final class X2Tests: XCTestCase {
    func testX2TwentyWarmRunsWithinBudget() throws {
        let input = try Paths.fixture("fixture-20k.md")
        let core = try Core()
        print("X2 input fixture-20k.md: \(input.utf16.count) UTF-16 units; bundle loaded once in \(String(format: "%.1f", core.loadMs)) ms (not timed)")
        let timing = try FourTypeTiming.run(core: core, input: input)
        timing.report("X2").forEach { print($0) }
        XCTAssertLessThanOrEqual(timing.median, 300)
    }
}
