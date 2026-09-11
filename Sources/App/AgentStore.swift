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

    var onTransition: ((Transition) -> Void)?

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
        for transition in result.transitions {
            onTransition?(transition)
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

    var blockedCount: Int { agents.filter { $0.status == .blocked }.count }

    func agents(forHost host: String) -> [TrackedAgent] {
        agents.filter { $0.host == host }
    }

    private func rebuild() {
        agents = bySession.values.flatMap { $0 }.sorted(by: Self.ordered)
    }

    static func rank(_ status: AgentStatus) -> Int {
        switch status {
        case .blocked: return 0
        case .working: return 1
        case .done: return 2
        case .idle: return 3
        case .unknown: return 4
        }
    }

    private static func ordered(_ a: TrackedAgent, _ b: TrackedAgent) -> Bool {
        let ra = rank(a.status), rb = rank(b.status)
        return ra != rb ? ra < rb : a.key < b.key
    }
}
