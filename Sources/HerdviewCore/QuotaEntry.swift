import Foundation

/// Why a Provider's row cannot show fresh numbers.
public enum QuotaProblem: Equatable, Sendable {
    case signInExpired
    case noSubscription
    case rateLimited
    case failed(String)

    public func message(for provider: QuotaProvider) -> String {
        switch self {
        case .signInExpired: return "sign-in expired — run \(provider.signInCommand)"
        case .noSubscription: return "no Go subscription"
        case .rateLimited: return "rate limited"
        case .failed(let reason): return reason
        }
    }
}

/// What the Quota card knows about one Provider.
public enum QuotaEntry: Equatable, Sendable {
    /// Before the first fetch has finished.
    case loading
    case notSignedIn
    case ok(QuotaReport)
    /// `last` is the most recent successful report, however old: an expired
    /// sign-in means the CLI has not run, so its Quota has not moved either.
    case problem(QuotaProblem, last: QuotaReport?)

    public var lastReport: QuotaReport? {
        switch self {
        case .ok(let report): return report
        case .problem(_, let last): return last
        case .loading, .notSignedIn: return nil
        }
    }

    /// The entry once a fetch has come to `outcome`.
    public func applying(_ outcome: QuotaOutcome, provider: QuotaProvider, now: Date) -> QuotaEntry {
        switch outcome {
        case .report(let windows):
            return .ok(QuotaReport(provider: provider, windows: windows, fetchedAt: now))
        case .signInExpired:
            return .problem(.signInExpired, last: lastReport)
        case .noSubscription:
            return .problem(.noSubscription, last: nil)
        case .rateLimited:
            return .problem(.rateLimited, last: lastReport)
        case .failed(let reason):
            return .problem(.failed(reason), last: lastReport)
        }
    }
}

/// When a Provider is fetched. Only while the window is visible: every
/// `pollInterval` on the tick, and at once when the window is shown, but not
/// more than once every `showDebounce`.
public enum QuotaSchedule {
    public static let pollInterval: TimeInterval = 5 * 60
    public static let showDebounce: TimeInterval = 60

    public enum Trigger: Sendable {
        case tick
        case shown
    }

    public static func isDue(_ trigger: Trigger, lastStarted: Date?, rateLimitedUntil: Date?, now: Date) -> Bool {
        if let until = rateLimitedUntil, now < until { return false }
        guard let last = lastStarted else { return true }
        let gap = trigger == .tick ? pollInterval : showDebounce
        return now.timeIntervalSince(last) >= gap
    }
}
