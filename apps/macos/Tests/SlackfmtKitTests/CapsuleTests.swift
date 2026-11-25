import Foundation
import SlackfmtKit
import XCTest

final class CapsuleTests: XCTestCase {
    private let size = CGSize(width: 180, height: 36)
    private let builtIn = Capsule.Screen(
        frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
        visibleFrame: CGRect(x: 0, y: 70, width: 1728, height: 1014))
    private let external = Capsule.Screen(
        frame: CGRect(x: 1728, y: -200, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1728, y: -200, width: 1920, height: 1055))

    func testCentresOnTheSecondScreenWhenThePointerIsOnIt() throws {
        let frame = try XCTUnwrap(Capsule.frame(size: size, screens: [builtIn, external], pointer: CGPoint(x: 2000, y: 300)))
        XCTAssertEqual(frame.midX, external.frame.midX)
        XCTAssertEqual(frame.minY, external.visibleFrame.minY + 72)
        XCTAssertEqual(frame.size, size)
    }

    func testCentresOnTheFirstScreenAndClearsTheDock() throws {
        let frame = try XCTUnwrap(Capsule.frame(size: size, screens: [builtIn, external], pointer: CGPoint(x: 10, y: 10)))
        XCTAssertEqual(frame.midX, builtIn.frame.midX)
        XCTAssertEqual(frame.minY, 142)
    }

    func testTakesTheFirstScreenWhenThePointerIsOnNone() throws {
        let frame = try XCTUnwrap(Capsule.frame(size: size, screens: [builtIn, external], pointer: CGPoint(x: -50, y: 5000)))
        XCTAssertEqual(frame.midX, builtIn.frame.midX)
        XCTAssertNil(Capsule.frame(size: size, screens: [], pointer: .zero))
    }

    func testHoldsThePointersScreenAtItsTopEdge() throws {
        let frame = try XCTUnwrap(Capsule.frame(size: size, screens: [builtIn, external], pointer: CGPoint(x: 100, y: 1117)))
        XCTAssertEqual(frame.midX, builtIn.frame.midX)
    }

    func testFadesByV9AndNotAtAllWithReduceMotion() {
        XCTAssertEqual(Capsule.Timing(reduceMotion: false), Capsule.Timing(fadeIn: 0.12, hold: 1.0, fadeOut: 0.2))
        XCTAssertEqual(Capsule.Timing(reduceMotion: true), Capsule.Timing(fadeIn: 0, hold: 1.0, fadeOut: 0))
    }
}
