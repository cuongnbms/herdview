import Foundation

/// The Sessions a Jump has just opened a Terminal Tab or workspace for.
///
/// The new tab's Herdr client takes a moment to start, so a second Jump right
/// behind the first — a double click — finds no tab in `ps` and would open
/// another. For `window` seconds after a create, a Jump for the same Session
/// skips cmux's create step instead.
public struct RecentCreations: Sendable {
    /// How long a create covers later Jumps for its Session.
    public static let window: TimeInterval = 5

    private struct Key: Hashable, Sendable {
        let host: String
        let session: String
    }

    private var deadlines: [Key: Date] = [:]

    public init() {}

    /// Notes that a Jump created a tab or workspace for the Session at `now`.
    public mutating func record(host: String, session: String, now: Date) {
        deadlines = deadlines.filter { $0.value > now }
        deadlines[Key(host: host, session: session)] = now + Self.window
    }

    /// Whether a create for the Session is recent enough that a Jump at `now`
    /// should not create again.
    public func covers(host: String, session: String, now: Date) -> Bool {
        guard let deadline = deadlines[Key(host: host, session: session)] else { return false }
        return now < deadline
    }
}
