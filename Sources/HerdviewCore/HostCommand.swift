import Foundation

/// A command to run for a host: directly for local, wrapped in ssh for remote.
public struct HostCommand: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    public static func sessionList(for host: HostConfig) -> HostCommand {
        if let ssh = host.ssh {
            return HostCommand(
                executable: "/usr/bin/ssh",
                arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", ssh, "\(host.herdrPath) session list --json"])
        }
        return HostCommand(executable: host.herdrPath, arguments: ["session", "list", "--json"])
    }

    /// Moves Herdr's focus onto one Agent's pane. Focus lives on the Herdr
    /// server, so every client attached to the Session follows it — including
    /// one that attaches a moment later.
    public static func agentFocus(for host: HostConfig, session: String, paneId: String) -> HostCommand {
        if let ssh = host.ssh {
            return HostCommand(
                executable: "/usr/bin/ssh",
                arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", ssh,
                            "\(host.herdrPath) --session \(session) agent focus \(paneId)"])
        }
        return HostCommand(executable: host.herdrPath, arguments: ["--session", session, "agent", "focus", paneId])
    }
}
