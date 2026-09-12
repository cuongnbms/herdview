import XCTest
@testable import HerdviewCore

final class BlinkPhaseTests: XCTestCase {
    private let period = BlinkPhase.period

    /// The offset is a point on a circle, so 0 and a whole period are the same
    /// place. Comparing them as plain numbers would call them a period apart,
    /// and a clock reading a hair under a multiple of the period lands on the
    /// far side of that seam for no reason but floating point.
    private func assertSamePhase(_ a: Double, _ b: Double,
                                 _ message: String = "", line: UInt = #line) {
        let gap = abs(a - b).truncatingRemainder(dividingBy: period)
        XCTAssertLessThanOrEqual(min(gap, period - gap), 1e-9,
                                 message.isEmpty ? "\(a) vs \(b)" : message, line: line)
    }

    func testZeroAtTheDimmestPointOfTheBreath() {
        assertSamePhase(BlinkPhase.secondsSinceDimmest(clock: period / 2), 0)
        assertSamePhase(BlinkPhase.secondsSinceDimmest(clock: period * 1.5), 0)
    }

    /// The reference point of the clock is the top of the breath, so a row
    /// starting there is half a period past the dimmest.
    func testHalfAPeriodInAtTheBrightestPoint() {
        assertSamePhase(BlinkPhase.secondsSinceDimmest(clock: 0), period / 2)
        assertSamePhase(BlinkPhase.secondsSinceDimmest(clock: period), period / 2)
    }

    /// Two rows asked at the same instant must agree, whatever that instant is:
    /// the phase is a function of the clock, never of when a row appeared.
    func testPhaseDependsOnlyOnTheInstant() {
        let odd = 123_456.73
        XCTAssertEqual(BlinkPhase.secondsSinceDimmest(clock: odd),
                       BlinkPhase.secondsSinceDimmest(clock: odd + period),
                       accuracy: 1e-9)
        XCTAssertEqual(BlinkPhase.secondsSinceDimmest(clock: odd),
                       BlinkPhase.secondsSinceDimmest(clock: odd + period * 10),
                       accuracy: 1e-6)
    }

    /// The answer is how far the animation should be wound forward, so it has
    /// to be a real point inside one cycle — never negative, never a whole
    /// period or more, however the clock is read.
    func testStaysInsideOneCycle() {
        for clock in stride(from: -20.0, through: 20.0, by: 0.013) {
            let value = BlinkPhase.secondsSinceDimmest(clock: clock)
            XCTAssertGreaterThanOrEqual(value, 0, "clock \(clock)")
            XCTAssertLessThan(value, period, "clock \(clock)")
        }
    }

    /// Clock readings before zero are ordinary: a monotonic clock is only
    /// counted from an arbitrary point, so nothing may depend on its sign.
    func testHoldsForNegativeClockReadings() {
        assertSamePhase(BlinkPhase.secondsSinceDimmest(clock: -period / 2), 0)
        assertSamePhase(BlinkPhase.secondsSinceDimmest(clock: -period), period / 2)
    }

    /// Within a cycle it simply counts forward, one second per second.
    func testAdvancesWithTheClock() {
        let base = BlinkPhase.secondsSinceDimmest(clock: period / 2)
        XCTAssertEqual(BlinkPhase.secondsSinceDimmest(clock: period / 2 + 0.3) - base, 0.3,
                       accuracy: 1e-9)
    }
}
