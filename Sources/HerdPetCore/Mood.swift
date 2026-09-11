import Foundation

/// The single value the pet animates, chosen from all agents by priority.
public enum Mood: String, CaseIterable, Sendable, Equatable {
    case idle
    case working
    case blocked
    case done
}

public enum MoodResolver {
    public static func resolve(_ agents: [TrackedAgent]) -> Mood {
        if agents.contains(where: { $0.status == .blocked }) { return .blocked }
        if agents.contains(where: { $0.status == .working }) { return .working }
        if agents.contains(where: { $0.status == .done }) { return .done }
        return .idle
    }
}
