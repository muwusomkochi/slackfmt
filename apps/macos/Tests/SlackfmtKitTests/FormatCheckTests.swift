import AppKit
import SlackfmtKit
import XCTest

final class FormatCheckTests: XCTestCase {
    private var board: NSPasteboard!

    override func setUp() { board = NSPasteboard.withUniqueName() }
    override func tearDown() { board.releaseGlobally() }

    private func check(_ customData: Data?) -> FormatCheck {
        let item = NSPasteboardItem()
        item.setString("plain", forType: .string)
        if let customData { item.setData(customData, forType: PasteboardTypes.customData) }
        board.clearContents()
        board.writeObjects([item])
        return FormatCheck(board)
    }

    private func pickle(_ texty: String) -> Data {
        Pickle.encode([("public.utf8-plain-text", "x"), ("slack/texty", texty)])
    }

    func testMatchesASlackCopy() {
        XCTAssertEqual(check(pickle(#"{"ops":[{"insert":"hi\n"}]}"#)), .matches)
    }

    func testChangedWhenTheEntryIsNotADelta() {
        XCTAssertEqual(check(pickle(#"{"blocks":[]}"#)), .changed)
        XCTAssertEqual(check(pickle(#"{"ops":{}}"#)), .changed)
        XCTAssertEqual(check(pickle(#"[{"insert":"hi"}]"#)), .changed)
        XCTAssertEqual(check(pickle("not json")), .changed)
    }

    func testChangedWhenThereIsNoSlackEntry() {
        XCTAssertEqual(check(Pickle.encode([("text/other", "x")])), .changed)
    }

    func testChangedWhenTheBytesDoNotDecode() {
        XCTAssertEqual(check(Data([1, 2, 3, 4, 5])), .changed)
    }

    func testAbsentWithoutTheCustomType() {
        XCTAssertEqual(check(nil), .absent)
    }

    func testEachResultCarriesItsStringFromThePRD() {
        XCTAssertEqual(FormatCheck.matches.message, "Slack's format still matches")
        XCTAssertEqual(FormatCheck.changed.message, "Slack's format changed: formatted pastes may break")
        XCTAssertEqual(FormatCheck.absent.message, "No Slack format on the clipboard. Copy a formatted message in Slack first")
    }
}
