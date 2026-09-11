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
