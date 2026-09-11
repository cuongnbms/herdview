import Foundation

/// One line of the pet's bubble: an agent worth reporting on, named by host.
public struct AgentBubbleRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let host: String
    public let status: AgentStatus

    public init(id: String, name: String, host: String, status: AgentStatus) {
        self.id = id
        self.name = name
        self.host = host
        self.status = status
    }
}

/// What the bubble draws, plus however many agents the cap left out.
public struct AgentBubbleContent: Equatable, Sendable {
    public let rows: [AgentBubbleRow]
    public let overflow: Int

    public static let empty = AgentBubbleContent(rows: [], overflow: 0)

    public init(rows: [AgentBubbleRow], overflow: Int) {
        self.rows = rows
        self.overflow = overflow
    }

    /// Lines the bubble needs, counting the "+N more" line. Drives panel height.
    public var lineCount: Int {
        rows.isEmpty ? 0 : rows.count + (overflow > 0 ? 1 : 0)
    }
}

/// Builds the pet's bubble from the tracked agents: the ones doing something
/// (blocked, working, done), the most attention-worthy first, capped so a busy
/// herd does not grow a bubble taller than the screen.
public enum AgentBubbleRows {
    public static let defaultLimit = 5

    public static func content(from agents: [TrackedAgent], limit: Int = defaultLimit) -> AgentBubbleContent {
        let reported = agents
            .filter { $0.status == .blocked || $0.status == .working || $0.status == .done }
            .sorted { a, b in
                let ra = a.status.attentionRank, rb = b.status.attentionRank
                return ra != rb ? ra < rb : a.key < b.key
            }
        let shown = reported.prefix(max(limit, 1))
        return AgentBubbleContent(
            rows: shown.map {
                AgentBubbleRow(id: $0.key, name: $0.info.displayName, host: $0.host, status: $0.status)
            },
            overflow: reported.count - shown.count
        )
    }
}
