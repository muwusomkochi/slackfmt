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

    /// R38, R39, R41, R43 and R44, on the engine the app runs, as the core tests expect them (A18 holds R40 and R42).
    func testRev7sLinesConvertAsTheyDoInNode() throws {
        let converter = try converter()
        for (input, format, expected) in [
            (
                #"<b style="font-weight:normal;"><p><span style="font-weight:700">Bold</span><span style="font-weight:400"> and </span><span style="font-style:italic">italic</span> <span style="text-decoration:line-through">~struck</span></p></b>"#,
                Converter.Format.html,
                #"{"ops":[{"insert":"Bold","attributes":{"bold":true}},{"insert":" and "},{"insert":"italic","attributes":{"italic":true}},{"insert":" "},{"insert":"~struck","attributes":{"strike":true}},{"insert":"\n"}]}"#
            ),
            (
                "<html><head><title>Title</title><style>p { color: red }</style></head><body><p>un<em>believ</em>able</p></body></html>",
                .html,
                #"{"ops":[{"insert":"un"},{"insert":"believ","attributes":{"italic":true}},{"insert":"able\n"}]}"#
            ),
            (
                "<p>Run</p><pre>a\n  b</pre>",
                .html,
                #"{"ops":[{"insert":"Run\n\na"},{"insert":"\n","attributes":{"code-block":true}},{"insert":"  b"},{"insert":"\n","attributes":{"code-block":true}}]}"#
            ),
            (
                "1. one\n   ```\n   a\n   ```\n2. two",
                .detect,
                #"{"ops":[{"insert":"one"},{"insert":"\n","attributes":{"list":"ordered"}},{"insert":"a"},{"insert":"\n","attributes":{"code-block":true}},{"insert":"2. two\n"}]}"#
            ),
        ] {
            XCTAssertEqual(try converter.convert(input, format: format).delta, expected, input)
        }
    }
}
