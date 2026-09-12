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

    private var bySession: [String: [TrackedAgent]] = [:]

    func setHostOrder(_ names: [String]) {
        hostOrder = names
    }

    func apply(host: String, session: String, snapshot: [AgentInfo], now: Date = Date()) {
        let key = "\(host)/\(session)"
        let result = AgentSnapshotReducer.reduce(previous: bySession[key] ?? [], snapshot: snapshot,
                                                 host: host, session: session, now: now)
        bySession[key] = result.agents
        rebuild()
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

    var blockedCount: Int { agents.filter { $0.status == .blocked }.count }

    func agents(forHost host: String) -> [TrackedAgent] {
        agents.filter { $0.host == host }
    }

    private func rebuild() {
        agents = bySession.values.flatMap { $0 }.sorted(by: AgentOrder.before)
    }
}
