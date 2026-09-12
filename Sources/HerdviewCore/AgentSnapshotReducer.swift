import Foundation

public struct ReduceResult: Equatable, Sendable {
    public let agents: [TrackedAgent]
    public let transitions: [Transition]

    public init(agents: [TrackedAgent], transitions: [Transition]) {
        self.agents = agents
        self.transitions = transitions
    }
}

/// Folds one `agent.list` snapshot for one (host, session) into the tracked set.
public enum AgentSnapshotReducer {
    public static func reduce(previous: [TrackedAgent], snapshot: [AgentInfo],
                              host: String, session: String, now: Date) -> ReduceResult {
        let previousByKey = Dictionary(uniqueKeysWithValues: previous.map { ($0.key, $0) })
        var agents: [TrackedAgent] = []
        var transitions: [Transition] = []

        for info in snapshot {
            let key = TrackedAgent.key(host: host, session: session, paneId: info.paneId)
            guard let old = previousByKey[key] else {
                agents.append(TrackedAgent(host: host, session: session, info: info, since: now))
                continue
            }
            if info.revision < old.info.revision {
                agents.append(old)
                continue
            }
            if info.agentStatus != old.status {
                let updated = TrackedAgent(host: host, session: session, info: info, since: now)
                agents.append(updated)
                transitions.append(Transition(agent: updated, from: old.status, to: info.agentStatus))
            } else {
                var refreshed = old
                refreshed.info = info
                agents.append(refreshed)
            }
        }
        return ReduceResult(agents: agents, transitions: transitions)
    }
}
