import Foundation

/// Herdr's agent status, taken verbatim. Unknown raw values decode as `.unknown`
/// so a newer Herdr never breaks decoding.
public enum AgentStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case idle
    case working
    case blocked
    case done
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AgentStatus(rawValue: raw) ?? .unknown
    }
}

public extension AgentStatus {
    /// Which agent to show first: the ones waiting on a human, then the busy
    /// ones, then the finished ones. Orders both the menu list and the bubble.
    var attentionRank: Int {
        switch self {
        case .blocked: return 0
        case .working: return 1
        case .done: return 2
        case .idle: return 3
        case .unknown: return 4
        }
    }
}

public extension AgentStatus {
    /// Whether an agent in this status is waiting on a human: one to unblock
    /// it, one to collect what it finished. It is the single rule behind both
    /// ways Herdview asks for attention — the row that blinks and the
    /// notification that is posted — so the two can never disagree about which
    /// agents are asking.
    var asksForAPerson: Bool {
        self == .blocked || self == .done
    }
}
