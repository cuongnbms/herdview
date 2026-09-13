import Foundation

/// The macOS notification one Transition is worth, or nothing.
///
/// A Highlight — the blinking row — only reaches someone who is looking at the
/// window. A Notice is the same news for someone who is not, so it says the
/// same three things the row says, in the same order, and never names an agent
/// a second way.
public struct TransitionNotice: Equatable, Sendable {
    /// The agent's key. One banner per agent: the next one it earns replaces
    /// the one already on screen instead of stacking beneath it.
    public let identifier: String
    /// The host, so a machine's banners group together the way the window's
    /// sections do.
    public let threadIdentifier: String
    public let title: String
    public let subtitle: String
    public let body: String

    public init(identifier: String, threadIdentifier: String,
                title: String, subtitle: String, body: String) {
        self.identifier = identifier
        self.threadIdentifier = threadIdentifier
        self.title = title
        self.subtitle = subtitle
        self.body = body
    }
}

public extension TransitionNotice {
    /// Nil unless the Transition landed on a status that is asking for a
    /// person. Where it came from never matters: idle straight to blocked is
    /// asking just as loudly as working to blocked. The statuses left out flip
    /// back and forth on their own every poll, and a banner for those would
    /// interrupt to say nothing.
    init?(_ transition: Transition) {
        guard transition.to.asksForAPerson else { return nil }
        let agent = transition.agent
        let row = AgentTitles.rowText(for: agent)
        // The session rides in brackets after the directory, and is absent
        // when it is already the title — nothing is printed twice.
        let title = row.session.map { "\(row.primary) (\($0))" } ?? row.primary
        self.init(identifier: agent.key,
                  threadIdentifier: agent.host,
                  title: title,
                  subtitle: "\(transition.to.rawValue) on \(agent.host)",
                  body: row.secondary)
    }
}
