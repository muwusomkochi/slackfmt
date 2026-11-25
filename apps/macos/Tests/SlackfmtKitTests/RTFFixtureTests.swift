import AppKit
import SlackfmtKit
import XCTest

/// §8's RTF fixtures and the HTML their references are made from (V23). WRITE_FIXTURES=1 writes them; without it, the
/// committed HTML must equal what V18's path makes of the committed RTF.
final class RTFFixtureTests: XCTestCase {
    private let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fixtures")
    private let limit = 20_000

    private func largestRTF() throws -> Data {
        let html = try String(contentsOf: fixtures.appendingPathComponent("fixture.html"), encoding: .utf8)
        var largest = Data()
        for count in 1... {
            let rtf = try RichText.rtf(fromHTML: String(repeating: html, count: count))
            if rtf.count > limit { break }
            largest = rtf
        }
        return largest
    }

    private func boldLine() throws -> Data {
        let string = NSAttributedString(string: "rtf wins", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)])
        return try string.data(from: NSRange(location: 0, length: string.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    func testRTFFixturesAndTheirHTML() throws {
        let writing = ProcessInfo.processInfo.environment["WRITE_FIXTURES"] == "1"
        for (name, make) in [("fixture-20k", largestRTF), ("a17", boldLine)] {
            let rtf = fixtures.appendingPathComponent("\(name).rtf")
            let html = fixtures.appendingPathComponent("\(name).rtf.html")
            if writing {
                try make().write(to: rtf)
                try RichText.html(fromRTF: Data(contentsOf: rtf)).write(to: html, atomically: true, encoding: .utf8)
            }
            let data = try Data(contentsOf: rtf)
            XCTAssertLessThanOrEqual(data.count, limit, name)
            XCTAssertEqual(try RichText.html(fromRTF: data), try String(contentsOf: html, encoding: .utf8), name)
        }
    }
}
