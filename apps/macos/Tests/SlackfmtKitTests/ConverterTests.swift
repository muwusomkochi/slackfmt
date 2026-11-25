import SlackfmtKit
import XCTest

final class ConverterTests: XCTestCase {
    private func converter(_ body: String) throws -> Converter {
        try Converter(script: "globalThis.slackfmt = { convert: \(body) };")
    }

    private let echo = "async (text, format) => ({ delta: 'd:' + text, html: 'h:' + format, plain: 'p' })"

    func testReturnsWhatTheScriptResolves() throws {
        let result = try converter(echo).convert("hi", format: .html)
        XCTAssertEqual(result, Conversion(delta: "d:hi", html: "h:html", plain: "p"))
    }

    func testLeavesPlainTextToTheScriptsOwnDetection() throws {
        XCTAssertEqual(try converter(echo).convert("hi", format: .detect).html, "h:undefined")
    }

    func testThrowsWhenThePromiseRejects() throws {
        XCTAssertThrowsError(try converter("async () => { throw new Error('no'); }").convert("hi", format: .detect))
    }

    func testThrowsWhenTheScriptThrows() throws {
        XCTAssertThrowsError(try converter("() => { throw new Error('no'); }").convert("hi", format: .detect))
    }

    func testThrowsWhenThePromiseNeverSettles() throws {
        XCTAssertThrowsError(try converter("() => new Promise(() => {})").convert("hi", format: .detect))
    }

    func testThrowsWhenTheResultIsNotAConversion() throws {
        XCTAssertThrowsError(try converter("async () => ({ delta: 'd' })").convert("hi", format: .detect))
    }

    func testConvertsAgainAfterThrowing() throws {
        let sometimes = try converter("async (text) => { if (text === 'bad') throw new Error('no'); return { delta: text, html: '', plain: '' }; }")
        XCTAssertThrowsError(try sometimes.convert("bad", format: .detect))
        XCTAssertEqual(try sometimes.convert("good", format: .detect).delta, "good")
    }

    func testThrowsForTheTestHook() throws {
        let hooked = try converter(echo)
        hooked.throwsForTesting = true
        XCTAssertThrowsError(try hooked.convert("hi", format: .detect))
    }

    func testRefusesAScriptThatDoesNotLoad() {
        XCTAssertThrowsError(try Converter(script: "throw new Error('no');"))
        XCTAssertThrowsError(try Converter(script: "globalThis.other = 1;"))
    }
}
