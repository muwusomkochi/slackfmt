import SlackfmtKit
import XCTest

final class PickleTests: XCTestCase {
    func testEncodesOneEntryAsV3LaysItOut() {
        let bytes = [UInt8](Pickle.encode([("ab", "c")]))
        XCTAssertEqual(bytes, [
            0x14, 0, 0, 0,
            0x01, 0, 0, 0,
            0x02, 0, 0, 0, 0x61, 0, 0x62, 0,
            0x01, 0, 0, 0, 0x63, 0, 0, 0,
        ])
    }

    func testCountsUTF16CodeUnitsNotCharacters() throws {
        let decoded = try Pickle.decode(Pickle.encode([("t", "😀☐")]))
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].value, "😀☐")
    }

    func testDecodesSeveralEntries() throws {
        let decoded = try Pickle.decode(Pickle.encode([("public.utf8-plain-text", "hi"), ("slack/texty", "{}")]))
        XCTAssertEqual(decoded.map(\.type), ["public.utf8-plain-text", "slack/texty"])
        XCTAssertEqual(decoded.map(\.value), ["hi", "{}"])
    }

    func testRefusesBytesThatAreNotV3() {
        let good = Pickle.encode([("slack/texty", "{}")])
        XCTAssertThrowsError(try Pickle.decode(Data([1, 2, 3])))
        XCTAssertThrowsError(try Pickle.decode(good.dropLast(4)))
        XCTAssertThrowsError(try Pickle.decode(good + Data([0, 0, 0, 0])))
        var oversized = good
        oversized[8] = 0xFF
        XCTAssertThrowsError(try Pickle.decode(oversized))
    }
}
