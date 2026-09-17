import Foundation

/// What one fetch of one Provider's Quota came to.
///
/// The UI needs to tell three very different things apart that a bare
/// success/failure boolean cannot: a real report, a sign-in the CLI must
/// refresh, and an account that simply has no subscription. Keeping them as
/// cases also means no call site has to re-inspect the status code, and no
/// case ever carries the response body.
public enum QuotaOutcome: Equatable, Sendable {
    case report([QuotaWindow])
    case signInExpired
    case noSubscription
    case rateLimited(until: Date)
    case failed(String)

    /// How long a 429 without a usable `Retry-After` keeps a Provider quiet:
    /// long enough not to hammer an endpoint that is already refusing.
    public static let defaultRetryAfter: TimeInterval = 15 * 60
    /// The longest a `Retry-After` is obeyed, so a bad header cannot silence a
    /// Provider for a day.
    public static let maxRetryAfter: TimeInterval = 60 * 60

    /// Maps one fetch to its Outcome. `body` is read only to tell "no
    /// subscription" from "signed out" and to parse Windows; it is never kept
    /// or logged.
    public static func classify(provider: QuotaProvider, status: Int, body: Data,
                                retryAfter: String?, now: Date) -> QuotaOutcome {
        switch status {
        case 200:
            // A 200 the parser cannot read means the endpoint changed shape,
            // not that the account has no limits. Reporting failure keeps the
            // card from showing an empty row that reads as "nothing used".
            let windows = QuotaParsers.windows(for: provider, from: body)
            return windows.isEmpty ? .failed("unreadable response") : .report(windows)
        case 401:
            return .signInExpired
        case 403:
            if provider == .opencodeGo && errorType(in: body) == "EntitlementError" {
                return .noSubscription
            }
            return .signInExpired
        case 429:
            return .rateLimited(until: now.addingTimeInterval(retryDelay(retryAfter)))
        default:
            return .failed("HTTP \(status)")
        }
    }

    /// `Retry-After` in seconds. The HTTP-date form is not worth parsing for a
    /// delay that is capped at an hour anyway; it gets the default. A header
    /// that is zero, negative or not a number is no better than a missing one.
    static func retryDelay(_ header: String?) -> TimeInterval {
        guard let text = header?.trimmingCharacters(in: .whitespaces),
              let seconds = Double(text), seconds > 0 else { return defaultRetryAfter }
        return min(seconds, maxRetryAfter)
    }

    /// OpenCode's error body: `{"type":"error","error":{"type":"…","message":"…"}}`.
    /// Only the type is read — the message is free text and may echo a token.
    private static func errorType(in body: Data) -> String? {
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        return (json?["error"] as? [String: Any])?["type"] as? String
    }

    /// For the log. Never carries a token or a response body: `.failed` only
    /// ever holds a reason this type built itself.
    public var logDescription: String {
        switch self {
        case .report(let windows): return "ok, \(windows.count) window(s)"
        case .signInExpired: return "sign-in expired"
        case .noSubscription: return "no subscription"
        case .rateLimited(let until): return "rate limited until \(until)"
        case .failed(let reason): return "failed: \(reason)"
        }
    }
}
