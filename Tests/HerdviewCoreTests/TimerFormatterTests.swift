import XCTest
@testable import HerdviewCore

final class TimerFormatterTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 0)

    func testSecondsAndMinutes() {
        XCTAssertEqual(TimerFormatter.string(from: start, to: start.addingTimeInterval(5)), "0:05")
        XCTAssertEqual(TimerFormatter.string(from: start, to: start.addingTimeInterval(754)), "12:34")
    }

    func testHours() {
        XCTAssertEqual(TimerFormatter.string(from: start, to: start.addingTimeInterval(3_723)), "1:02:03")
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(TimerFormatter.string(from: start, to: start.addingTimeInterval(-9)), "0:00")
    }
}
