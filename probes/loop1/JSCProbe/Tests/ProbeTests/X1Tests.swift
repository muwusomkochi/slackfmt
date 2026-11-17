import ProbeKit
import XCTest

final class X1Tests: XCTestCase {
    func testX1BundleConvertsBothFixtures() throws {
        let bundle = try Data(contentsOf: Paths.bundle)
        let core = try Core()
        print("X1 bundle \(Paths.bundle.lastPathComponent): \(bundle.count) bytes, sha256 \(sha256(bundle)), loaded in \(String(format: "%.1f", core.loadMs)) ms")
        var failed: [String] = []
        for (name, format) in [("fixture.md", "markdown"), ("fixture.html", "html")] {
            let input = try Paths.fixture(name)
            do {
                let delta = try core.convert(input, format: format)
                try delta.write(to: Paths.fixtures.appendingPathComponent("\(name).jsc.delta.json"), atomically: true, encoding: .utf8)
                print("X1 \(name) as \(format): converted; \(try summarize(delta: delta)); Delta \(delta.utf8.count) bytes, sha256 \(sha256(delta))")
            } catch {
                failed.append(name)
                print("X1 \(name) as \(format): failed: \(error)")
            }
        }
        XCTAssertEqual(failed, [], "X1 failed for \(failed)")
    }
}
