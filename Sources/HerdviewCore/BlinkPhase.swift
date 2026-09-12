import Foundation

/// Where in the blink the clock is. A blinking row asks the clock rather than
/// starting a beat of its own, so every row that is blinking breathes in step
/// with every other one, and a row that scrolls out of the list and back has
/// no phase of its own to lose.
///
/// The breath itself is drawn by Core Animation, which needs to be told only
/// one thing: how far into the cycle to start. That is all this computes.
public enum BlinkPhase {
    /// One full breath: up from the dim end to the bright end and back.
    public static let period: TimeInterval = 1.4

    /// How long ago the breath was last at its dimmest, for the given reading
    /// of the clock — which is where an animation running from dim to bright
    /// and back must be wound to, to be in step with every other row.
    ///
    /// The caller passes a *monotonic* clock (`CACurrentMediaTime`), not a
    /// date. Wall time jumps when the machine sleeps or the clock is set, and
    /// a row that appeared after such a jump would compute a different offset
    /// from the rows already breathing, and drift away from them. Taking any
    /// clock value as a plain number also leaves this testable without one.
    public static func secondsSinceDimmest(clock: TimeInterval) -> TimeInterval {
        let elapsed = (clock - period / 2).truncatingRemainder(dividingBy: period)
        return elapsed < 0 ? elapsed + period : elapsed
    }
}
