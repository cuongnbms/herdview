import Foundation

/// How an agent is named on screen. Most panes are never named, so the title
/// falls back to what is most recognizable: the terminal's own title (set by
/// the running agent, e.g. "MME forecast integration"), then the working
/// directory, and only last the pane id.
public enum AgentTitles {
    /// The title for one agent, before disambiguation.
    public static func baseTitle(for info: AgentInfo) -> String {
        if let name = nonBlank(info.name) { return name }
        if let title = nonBlank(info.terminalTitleStripped) { return title }
        if let title = nonBlank(info.terminalTitle) { return title }
        if let cwd = nonBlank(info.cwd) { return URL(fileURLWithPath: cwd).lastPathComponent }
        return info.paneId
    }

    /// Display names keyed by agent key. Agents on the same host that would
    /// otherwise share a title (e.g. two unnamed pi panes both titled
    /// "π - bmx-core-service") get a pane suffix so the rows stay apart.
    /// Uniquely titled agents are returned unchanged.
    public static func displayNames(for agents: [TrackedAgent]) -> [String: String] {
        var result: [String: String] = [:]
        for hostGroup in Dictionary(grouping: agents, by: \.host).values {
            var counts: [String: Int] = [:]
            for agent in hostGroup { counts[baseTitle(for: agent.info), default: 0] += 1 }
            for agent in hostGroup {
                let base = baseTitle(for: agent.info)
                if counts[base, default: 0] > 1 {
                    result[agent.key] = "\(base) · \(shortPaneId(agent.info.paneId))"
                } else {
                    result[agent.key] = base
                }
            }
        }
        return result
    }

    /// The short end of a pane id: "w2:p6" to "p6". Falls back to the full id
    /// when it has no colon.
    public static func shortPaneId(_ paneId: String) -> String {
        paneId.split(separator: ":").last.map(String.init) ?? paneId
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
