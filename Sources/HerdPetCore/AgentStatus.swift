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
