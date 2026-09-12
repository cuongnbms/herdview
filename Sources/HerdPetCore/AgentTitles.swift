import Foundation

/// The two lines of an agent's row. The working directory is what you scan a
/// list of agents for, so it leads; the session rides quietly beside it, and
/// what the agent calls itself goes underneath.
public struct AgentRowText: Equatable, Sendable {
    public let primary: String
    /// Sits next to `primary` in the smaller, quieter type. Nil when the
    /// session is already the first line and repeating it would say nothing.
    public let session: String?
    public let secondary: String

    public init(primary: String, session: String?, secondary: String) {
        self.primary = primary
        self.session = session
        self.secondary = secondary
    }
}

/// How an agent is named on screen. The working directory is not always there;
/// when it is missing the session leads instead, and nothing is ever printed
/// twice in the same row.
public enum AgentTitles {
    public static func rowText(for agent: TrackedAgent) -> AgentRowText {
        let label = label(for: agent.info) ?? agent.info.paneId
        guard let directory = directory(for: agent.info) else {
            return AgentRowText(primary: agent.session, session: nil, secondary: label)
        }
        return AgentRowText(primary: directory, session: agent.session, secondary: label)
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
