import SlackfmtKit
import XCTest

/// The fork's core, bundled, in a JSContext: the same Deltas Node gives (A14, A17, A18, R31).
final class BundleTests: XCTestCase {
    private static let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private let fixtures = BundleTests.package.appendingPathComponent("Tests/fixtures")

    private func converter() throws -> Converter {
        try Converter(script: String(contentsOf: Self.package.appendingPathComponent("build/slackfmt.js"), encoding: .utf8))
    }

    private func read(_ name: String) throws -> String {
        try String(contentsOf: fixtures.appendingPathComponent(name), encoding: .utf8)
    }

    func testA14FixtureHTMLConvertsWithoutABrowserDOM() throws {
        XCTAssertEqual(try converter().convert(read("fixture.html"), format: .html).delta, try read("fixture-html.delta.json"))
    }

    func testFixtureMarkdownConvertsToItsReferenceAndPlainText() throws {
        let conversion = try converter().convert(read("fixture.md"), format: .detect)
        XCTAssertEqual(conversion.delta, try read("fixture.delta.json"))
        XCTAssertEqual(conversion.plain, try read("fixture.txt"))
        XCTAssertEqual(Pickle.encode([("slack/texty", conversion.delta)]), try Data(contentsOf: fixtures.appendingPathComponent("fixture.pickle")))
    }

    func testA18EachInputConvertsToItsReference() throws {
        let converter = try converter()
        let inputs = try FileManager.default.contentsOfDirectory(atPath: fixtures.appendingPathComponent("a18").path).sorted()
        XCTAssertEqual(inputs.count, 10)
        for input in inputs {
            let name = input.replacingOccurrences(of: ".txt", with: "")
            let delta = try converter.convert(read("a18/\(input)"), format: .detect).delta
            XCTAssertEqual(delta, try read("expected/a18-\(name).delta.json"), name)
            XCTAssertEqual(Pickle.encode([("slack/texty", delta)]), try Data(contentsOf: fixtures.appendingPathComponent("expected/a18-\(name).pickle")), name)
        }
    }

    func testThe20kFixturesConvertToTheirReferences() throws {
        let converter = try converter()
        for (input, format, expected) in [
            ("fixture-20k.md", Converter.Format.detect, "fixture-20k-md"),
            ("fixture-20k.html", .html, "fixture-20k-html"),
            ("fixture-20k.delta.json", .detect, "fixture-20k-delta"),
            ("fixture-20k.rtf.html", .html, "fixture-20k-rtf"),
            ("a17.rtf.html", .html, "a17-rtf"),
        ] {
            XCTAssertEqual(try converter.convert(read(input), format: format).delta, try read("expected/\(expected).delta.json"), input)
        }
    }
}
