import Foundation
import Combine
import HerdPetCore

/// Merged view of every watched session. Owned by the main actor; the UI observes it.
@MainActor
final class AgentStore: ObservableObject {
    @Published private(set) var agents: [TrackedAgent] = []
    @Published private(set) var hostOrder: [String] = []
    @Published private(set) var unreachableHosts: Set<String> = []
    @Published var configError: String?
    /// Rows flashing because their agent just turned blocked or done.
    @Published private(set) var highlighted: Set<String> = []

    /// How long a row stays tinted after its agent turns blocked or done.
    static let highlightSeconds: UInt64 = 3

    private var bySession: [String: [TrackedAgent]] = [:]
    private var highlightTasks: [String: Task<Void, Never>] = [:]

    func setHostOrder(_ names: [String]) {
        hostOrder = names
    }

    func apply(host: String, session: String, snapshot: [AgentInfo], now: Date = Date()) {
        let key = "\(host)/\(session)"
        let result = AgentSnapshotReducer.reduce(previous: bySession[key] ?? [], snapshot: snapshot,
                                                 host: host, session: session, now: now)
        bySession[key] = result.agents
        rebuild()
        // The store is where the transitions already are, so the tint is decided
        // here rather than by a hook the window would have to install.
        for transition in result.transitions {
            switch transition.to {
            case .blocked, .done: flash(agentKey: transition.agent.key)
            default: break
            }
        }
    }

    func removeSession(host: String, session: String) {
        bySession["\(host)/\(session)"] = nil
        rebuild()
    }

    func setReachable(host: String, _ reachable: Bool) {
        if reachable {
            unreachableHosts.remove(host)
        } else {
            unreachableHosts.insert(host)
        }
    }

    /// Tints one agent's row for `highlightSeconds`. Several rows can flash at
    /// once, and a second transition during a flash restarts its timer.
    func flash(agentKey: String) {
        highlighted.insert(agentKey)
        highlightTasks[agentKey]?.cancel()
        highlightTasks[agentKey] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.highlightSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            self?.highlighted.remove(agentKey)
            self?.highlightTasks[agentKey] = nil
        }
    }

    var blockedCount: Int { agents.filter { $0.status == .blocked }.count }

    func agents(forHost host: String) -> [TrackedAgent] {
        agents.filter { $0.host == host }
    }

    private func rebuild() {
        agents = bySession.values.flatMap { $0 }.sorted(by: AgentOrder.before)
    }
}
