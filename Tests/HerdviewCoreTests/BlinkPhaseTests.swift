import XCTest
@testable import HerdviewCore

final class BlinkPhaseTests: XCTestCase {
    /// Reference date itself starts on a bright half-beat, so every assertion
    /// below can be read as an offset from a known phase.
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    func testAlternatesEveryHalfPeriod() {
        XCTAssertTrue(BlinkPhase.isBright(at: start))
        XCTAssertTrue(BlinkPhase.isBright(at: start.addingTimeInterval(0.4)))
        XCTAssertFalse(BlinkPhase.isBright(at: start.addingTimeInterval(0.5)))
        XCTAssertFalse(BlinkPhase.isBright(at: start.addingTimeInterval(0.9)))
        XCTAssertTrue(BlinkPhase.isBright(at: start.addingTimeInterval(1.0)))
    }

    /// Two rows asked at the same instant must agree, whatever that instant is:
    /// the phase is a function of the clock, never of when a row appeared.
    func testPhaseDependsOnlyOnTheInstant() {
        let odd = Date(timeIntervalSinceReferenceDate: 123_456.73)
        XCTAssertEqual(BlinkPhase.isBright(at: odd), BlinkPhase.isBright(at: odd))
        XCTAssertNotEqual(BlinkPhase.isBright(at: odd),
                          BlinkPhase.isBright(at: odd.addingTimeInterval(BlinkPhase.halfPeriod)))
    }

    func testHoldsBeforeTheReferenceDate() {
        XCTAssertFalse(BlinkPhase.isBright(at: start.addingTimeInterval(-0.5)))
        XCTAssertTrue(BlinkPhase.isBright(at: start.addingTimeInterval(-1.0)))
    }
}
