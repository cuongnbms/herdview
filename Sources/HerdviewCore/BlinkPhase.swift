import Foundation

/// Which half-beat of the blink the clock is on. A blinking row asks the clock
/// rather than keeping a timer of its own, so every row that is blinking pulses
/// in step with every other one, and a row that scrolls out of the list and
/// back has no phase of its own to lose.
public enum BlinkPhase {
    /// How long each half of the blink lasts: bright for this long, then dim
    /// for this long, so a full beat is twice this. The window's tick must be
    /// no slower than this, or beats are missed.
    public static let halfPeriod: TimeInterval = 0.5

    public static func isBright(at date: Date) -> Bool {
        let beats = (date.timeIntervalSinceReferenceDate / halfPeriod).rounded(.down)
        return beats.truncatingRemainder(dividingBy: 2) == 0
    }
}
