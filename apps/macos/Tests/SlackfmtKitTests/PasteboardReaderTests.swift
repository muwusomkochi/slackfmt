import AppKit
import SlackfmtKit
import XCTest

final class PasteboardReaderTests: XCTestCase {
    private var board: NSPasteboard!

    override func setUp() {
        board = NSPasteboard.withUniqueName()
        board.clearContents()
    }

    override func tearDown() {
        board.releaseGlobally()
    }

    private func put(_ contents: [NSPasteboard.PasteboardType: Data]) {
        let item = NSPasteboardItem()
        for (type, data) in contents { item.setData(data, forType: type) }
        board.clearContents()
        board.writeObjects([item])
    }

    private func put(plain: String) { put([.string: Data(plain.utf8)]) }

    private func refusal() -> Refusal? {
        if case .refused(let refusal) = PasteboardReader.read(board) { return refusal }
        return nil
    }

    private func source() -> Source? {
        if case .source(let source) = PasteboardReader.read(board) { return source }
        return nil
    }

    private let slackCopy = Pickle.encode([("public.utf8-plain-text", "hi"), ("slack/texty", #"{"ops":[]}"#)])
    private let rtf = Data(#"{\rtf1\ansi rtf wins}"#.utf8)

    func testReadsTheHighestTypePresent() {
        put([.html: Data("<p>h</p>".utf8), .rtf: rtf, .string: Data("plain wins".utf8)])
        XCTAssertEqual(source(), .html("<p>h</p>"))
        put([.rtf: rtf, .string: Data("plain wins".utf8)])
        XCTAssertEqual(source(), .rtf(rtf))
        put([.html: Data("<p>h</p>".utf8), .string: Data("plain wins".utf8)])
        XCTAssertEqual(source(), .html("<p>h</p>"))
        put(plain: "plain wins")
        XCTAssertEqual(source(), .plain("plain wins"))
    }

    func testRefusesSlacksFormat() {
        put([PasteboardTypes.customData: slackCopy, .string: Data("hi".utf8)])
        XCTAssertEqual(refusal(), .slackFormat)
    }

    func testReadsPastACustomDataTypeThatIsNotSlacks() {
        put([PasteboardTypes.customData: Pickle.encode([("text/other", "x")]), .string: Data("hi".utf8)])
        XCTAssertEqual(source(), .plain("hi"))
        put([PasteboardTypes.customData: Data([1, 2, 3]), .string: Data("hi".utf8)])
        XCTAssertEqual(source(), .plain("hi"))
    }

    func testRefusesAnEmptySource() {
        XCTAssertEqual(refusal(), .empty)
        put(plain: "")
        XCTAssertEqual(refusal(), .empty)
        put(plain: " \n\t\n ")
        XCTAssertEqual(refusal(), .empty)
        put([NSPasteboard.PasteboardType("com.example.unknown"): Data("x".utf8)])
        XCTAssertEqual(refusal(), .empty)
    }

    func testRefusesEveryImageType() {
        for name in ["public.png", "public.tiff", "public.jpeg", "public.heic"] {
            put([NSPasteboard.PasteboardType(name): Data([0]), .html: Data("<img>".utf8), .string: Data("alt".utf8)])
            XCTAssertEqual(refusal(), .image, name)
        }
    }

    func testRefusesAFileURL() {
        put([.fileURL: Data("file:///tmp/x".utf8), .string: Data("x".utf8)])
        XCTAssertEqual(refusal(), .file)
    }

    func testRefusesAFinderFileCopyAsAFile() {
        put([.fileURL: Data("file:///tmp/made-up.txt".utf8), .tiff: Data([0]), .string: Data("made-up.txt".utf8)])
        XCTAssertEqual(refusal()?.message, "Files can't be converted")
    }

    func testRefusesAnImageOrFileOnAnyItem() {
        let text = NSPasteboardItem()
        text.setString("hi", forType: .string)
        let image = NSPasteboardItem()
        image.setData(Data([0]), forType: .png)
        board.clearContents()
        board.writeObjects([text, image])
        XCTAssertEqual(refusal(), .image)
    }

    func testPicksTheFirstRefusalThatApplies() {
        put([.png: Data([0]), .fileURL: Data("file:///tmp/x".utf8), PasteboardTypes.customData: slackCopy])
        XCTAssertEqual(refusal(), .image)
        put([.fileURL: Data("file:///tmp/x".utf8), PasteboardTypes.customData: slackCopy, .string: Data(" ".utf8)])
        XCTAssertEqual(refusal(), .file)
        put([PasteboardTypes.customData: slackCopy, .string: Data(" ".utf8)])
        XCTAssertEqual(refusal(), .slackFormat)
    }

    func testCountsTheLimitInUTF16CodeUnits() {
        put(plain: String(repeating: "a", count: 200_000))
        XCTAssertNotNil(source())
        put(plain: String(repeating: "a", count: 200_001))
        XCTAssertEqual(refusal(), .tooLong)
        put(plain: String(repeating: "😀", count: 100_000))
        XCTAssertNotNil(source())
        put(plain: String(repeating: "😀", count: 100_000) + "a")
        XCTAssertEqual(refusal(), .tooLong)
    }

    func testCountsTheLimitOnTheTypeReadOnly() {
        put([.html: Data("<p>short</p>".utf8), .string: Data(String(repeating: "a", count: 200_001).utf8)])
        XCTAssertEqual(source(), .html("<p>short</p>"))
        put([.html: Data(String(repeating: "a", count: 200_001).utf8), .string: Data("short".utf8)])
        XCTAssertEqual(refusal(), .tooLong)
        put([.rtf: Data(String(repeating: "a", count: 200_001).utf8), .string: Data("short".utf8)])
        XCTAssertEqual(refusal(), .tooLong)
    }

    func testEveryRefusalCarriesItsStringFromThePRD() {
        XCTAssertEqual(Refusal.allCases.map(\.message), [
            "Images can't be converted",
            "Files can't be converted",
            "Already Slack format",
            "Clipboard is empty",
            "Too long to convert",
            "Couldn't convert this",
        ])
    }
}
