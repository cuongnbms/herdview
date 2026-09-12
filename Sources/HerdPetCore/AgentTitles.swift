import Foundation

/// The two lines of an agent's row. The working directory is what you scan a
/// list of agents for, so it goes on top; the session and what the agent calls
/// itself sit underneath.
public struct AgentRowText: Equatable, Sendable {
    public let primary: String
    public let secondary: String

    public init(primary: String, secondary: String) {
        self.primary = primary
        self.secondary = secondary
    }
}

/// How an agent is named on screen. Neither the directory nor the title is
/// always there, so whichever one is missing lets the other move up a line;
/// nothing is ever printed on both lines at once.
public enum AgentTitles {
    public static func rowText(for agent: TrackedAgent) -> AgentRowText {
        let label = label(for: agent.info) ?? agent.info.paneId
        guard let directory = directory(for: agent.info) else {
            return AgentRowText(primary: label, secondary: agent.session)
        }
        return AgentRowText(primary: directory, secondary: "\(agent.session) · \(label)")
    }

    /// What the agent calls itself: the user-given name, else the terminal's
    /// own title (set by the running agent, e.g. "MME forecast integration").
    /// Nil when it has neither. The working directory is deliberately not a
    /// fallback: it is the line above.
    static func label(for info: AgentInfo) -> String? {
        nonBlank(info.name) ?? nonBlank(info.terminalTitleStripped) ?? nonBlank(info.terminalTitle)
    }

    /// The last component of the agent's working directory.
    static func directory(for info: AgentInfo) -> String? {
        guard let cwd = nonBlank(info.cwd) else { return nil }
        return nonBlank(URL(fileURLWithPath: cwd).lastPathComponent)
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
