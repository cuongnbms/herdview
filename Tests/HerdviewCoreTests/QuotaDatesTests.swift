import XCTest
@testable import HerdviewCore

final class QuotaDatesTests: XCTestCase {
    /// Claude and Grok send six fractional digits and a `+00:00` offset, which
    /// `ISO8601DateFormatter` refuses as is.
    func testSixFractionalDigitsAndAnOffset() throws {
        let date = try XCTUnwrap(QuotaDates.parse(iso: "2026-09-17T14:00:00.551304+00:00"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_789_653_600.551304, accuracy: 0.001)
    }

    /// OpenCode sends milliseconds and `Z`.
    func testMillisecondsAndZulu() throws {
        let date = try XCTUnwrap(QuotaDates.parse(iso: "2026-09-17T17:23:46.966Z"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_789_665_826.966, accuracy: 0.001)
    }

    func testNoFraction() throws {
        let date = try XCTUnwrap(QuotaDates.parse(iso: "2026-09-22T02:00:00+00:00"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_790_042_400, accuracy: 0.001)
    }

    func testNonUTCOffset() throws {
        let date = try XCTUnwrap(QuotaDates.parse(iso: "2026-09-17T21:00:00+07:00"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_789_653_600, accuracy: 0.001)
    }

    func testGarbageIsNil() {
        XCTAssertNil(QuotaDates.parse(iso: "soon"))
        XCTAssertNil(QuotaDates.parse(any: ""))
        XCTAssertNil(QuotaDates.parse(any: nil))
        XCTAssertNil(QuotaDates.parse(any: true))
    }

    /// Codex sends epoch seconds; a value too large to be seconds is milliseconds.
    func testEpochSecondsAndMilliseconds() {
        XCTAssertEqual(QuotaDates.parse(epoch: 1_790_250_529).timeIntervalSince1970, 1_790_250_529, accuracy: 0.001)
        XCTAssertEqual(QuotaDates.parse(epoch: 1_790_250_529_000).timeIntervalSince1970, 1_790_250_529, accuracy: 0.001)
    }

    func testAnyAcceptsNumbersNumericStringsAndISO() {
        XCTAssertEqual(QuotaDates.parse(any: NSNumber(value: 1_790_250_529))?.timeIntervalSince1970, 1_790_250_529)
        XCTAssertEqual(QuotaDates.parse(any: "1790250529")?.timeIntervalSince1970, 1_790_250_529)
        XCTAssertEqual(QuotaDates.parse(any: "2026-09-22T02:00:00Z")?.timeIntervalSince1970, 1_790_042_400)
    }
}
