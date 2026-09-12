import Foundation

/// An agent Herdview is tracking, with the moment its current status was observed.
public struct TrackedAgent: Equatable, Sendable {
    public let key: String
    public let host: String
    public let session: String
    public var info: AgentInfo
    /// When Herdview observed the current status. Herdr reports no timestamps,
    /// so this is observation time, not the real change time.
    public var since: Date

    public var status: AgentStatus { info.agentStatus }

    public init(host: String, session: String, info: AgentInfo, since: Date) {
        self.key = TrackedAgent.key(host: host, session: session, paneId: info.paneId)
        self.host = host
        self.session = session
        self.info = info
        self.since = since
    }

    public static func key(host: String, session: String, paneId: String) -> String {
        "\(host)/\(session)/\(paneId)"
    }
}

/// An observed status change of one tracked agent.
public struct Transition: Equatable, Sendable {
    public let agent: TrackedAgent
    public let from: AgentStatus
    public let to: AgentStatus

    public init(agent: TrackedAgent, from: AgentStatus, to: AgentStatus) {
        self.agent = agent
        self.from = from
        self.to = to
    }
}
