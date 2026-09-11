import Foundation

/// One agent as Herdr's `agent.list` reports it. Only the fields HerdPet uses
/// are decoded; everything else in the record is ignored.
public struct AgentInfo: Codable, Equatable, Sendable {
    public var paneId: String
    public var workspaceId: String
    public var tabId: String?
    public var agent: String?
    public var displayAgent: String?
    public var name: String?
    public var cwd: String?
    public var agentStatus: AgentStatus
    public var revision: UInt64

    enum CodingKeys: String, CodingKey {
        case paneId = "pane_id"
        case workspaceId = "workspace_id"
        case tabId = "tab_id"
        case agent
        case displayAgent = "display_agent"
        case name
        case cwd
        case agentStatus = "agent_status"
        case revision
    }

    public init(paneId: String, workspaceId: String, tabId: String? = nil, agent: String? = nil,
                displayAgent: String? = nil, name: String? = nil, cwd: String? = nil,
                agentStatus: AgentStatus, revision: UInt64) {
        self.paneId = paneId
        self.workspaceId = workspaceId
        self.tabId = tabId
        self.agent = agent
        self.displayAgent = displayAgent
        self.name = name
        self.cwd = cwd
        self.agentStatus = agentStatus
        self.revision = revision
    }

    /// The user-given agent name when there is one, else the pane id.
    public var displayName: String { name ?? paneId }
}
