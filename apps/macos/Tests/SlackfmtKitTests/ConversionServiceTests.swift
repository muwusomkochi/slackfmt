import AppKit
import SlackfmtKit
import XCTest

final class ConversionServiceTests: XCTestCase {
    private var source: NSPasteboard!
    private var destination: NSPasteboard!

    override func setUp() {
        source = NSPasteboard.withUniqueName()
        destination = NSPasteboard.withUniqueName()
        destination.clearContents()
        destination.setString("his clipboard", forType: .string)
    }

    override func tearDown() {
        source.releaseGlobally()
        destination.releaseGlobally()
    }

    private func service(_ body: String = ConversionServiceTests.bold) throws -> ConversionService {
        ConversionService(converter: try Converter(script: "globalThis.slackfmt = { convert: \(body) };"))
    }

    private static let bold = """
        async (text, format) => ({
          delta: JSON.stringify({ ops: [{ insert: text, attributes: { bold: true } }, { insert: '\\n' }] }),
          html: '<p><strong>' + text + '</strong> ☐</p>',
          plain: text,
        })
        """

    private func put(_ text: String) {
        source.clearContents()
        source.setString(text, forType: .string)
    }

    func testWritesSlacksFormatAndTheThreeCopiesBesideIt() throws {
        put("hi")
        XCTAssertEqual(try service().convert(from: source, to: destination), .converted)

        XCTAssertEqual(destination.pasteboardItems?.count, 1)
        let pickle = try XCTUnwrap(destination.data(forType: PasteboardTypes.customData))
        let entries = try Pickle.decode(pickle)
        XCTAssertEqual(entries.map(\.type), ["slack/texty"])
        XCTAssertEqual(entries[0].value, #"{"ops":[{"insert":"hi","attributes":{"bold":true}},{"insert":"\n"}]}"#)
        XCTAssertEqual(destination.string(forType: .string), "hi")
        let html = try XCTUnwrap(destination.string(forType: .html))
        XCTAssertTrue(html.contains("<p><strong>hi</strong> ☐</p>"))
        let rtf = try XCTUnwrap(destination.data(forType: .rtf))
        let rich = try NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertTrue(rich.string.contains("hi ☐"))
        let font = try XCTUnwrap(rich.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.bold))
    }

    func testDeclaresTheHTMLsEncoding() throws {
        put("hi")
        _ = try service().convert(from: source, to: destination)
        let html = try XCTUnwrap(destination.string(forType: .html))
        XCTAssertTrue(html.hasPrefix(#"<meta charset="utf-8">"#))
    }

    func testReplacesWhatTheClipboardHeld() throws {
        put("hi")
        _ = try service().convert(from: source, to: destination)
        XCTAssertNotEqual(destination.string(forType: .string), "his clipboard")
    }

    func testConvertsInPlace() throws {
        destination.clearContents()
        destination.setString("in place", forType: .string)
        XCTAssertEqual(try service().convert(from: destination, to: destination), .converted)
        XCTAssertEqual(destination.string(forType: .string), "in place")
        XCTAssertNotNil(destination.data(forType: PasteboardTypes.customData))
    }

    func testReadsRTFAsTheHTMLNSAttributedStringMakes() throws {
        let rich = NSAttributedString(string: "rtf wins", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)])
        let rtf = try rich.data(from: NSRange(location: 0, length: rich.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        source.clearContents()
        source.setData(rtf, forType: .rtf)
        let echo = "async (text, format) => ({ delta: JSON.stringify({ ops: [{ insert: format + ':' + text }] }), html: '<p>x</p>', plain: text })"
        XCTAssertEqual(try service(echo).convert(from: source, to: destination), .converted)
        let plain = try XCTUnwrap(destination.string(forType: .string))
        XCTAssertTrue(plain.contains("<b>rtf wins</b>"), plain)
        let delta = try Pickle.decode(XCTUnwrap(destination.data(forType: PasteboardTypes.customData)))[0].value
        XCTAssertTrue(delta.contains("html:"))
    }

    func testARefusalLeavesTheClipboardAsItWas() throws {
        put("  ")
        let before = destination.changeCount
        XCTAssertEqual(try service().convert(from: source, to: destination), .refused(.empty))
        XCTAssertEqual(destination.changeCount, before)
        XCTAssertEqual(destination.string(forType: .string), "his clipboard")
    }

    func testAConverterThatThrowsLeavesTheClipboardAsItWas() throws {
        put("hi")
        let before = destination.changeCount
        XCTAssertEqual(try service("async () => { throw new Error('no'); }").convert(from: source, to: destination), .refused(.converterError))
        XCTAssertEqual(destination.changeCount, before)
        XCTAssertEqual(destination.string(forType: .string), "his clipboard")
    }
}
