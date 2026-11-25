import AppKit
import SlackfmtKit
import XCTest

final class RichTextTests: XCTestCase {
    private func rtf(_ string: NSAttributedString) throws -> Data {
        try string.data(from: NSRange(location: 0, length: string.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    func testReadsRTFAsHTMLWithNoHeadOrStylesheet() throws {
        let bold = NSAttributedString(string: "rtf wins", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)])
        let html = try RichText.html(fromRTF: rtf(bold))
        XCTAssertTrue(html.contains("<b>rtf wins</b>"), html)
        for tag in ["<html", "<head", "<style", "<title", "<meta", "<!DOCTYPE", "<?xml"] {
            XCTAssertFalse(html.contains(tag), "\(tag) in \(html)")
        }
    }

    func testWritesRTFFromHTML() throws {
        let data = try RichText.rtf(fromHTML: #"<meta charset="utf-8"><p><strong>bold</strong> ☐ <a href="https://example.com/">link</a></p>"#)
        let rich = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertTrue(rich.string.hasPrefix("bold ☐ link"), rich.string)
        XCTAssertEqual((rich.attribute(.link, at: 7, effectiveRange: nil) as? URL)?.absoluteString, "https://example.com/")
    }
}
