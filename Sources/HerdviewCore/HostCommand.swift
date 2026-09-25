import Foundation

/// A command to run for a host: directly for local, wrapped in ssh for remote.
public struct HostCommand: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    /// Wraps a Herdr command locally or over SSH for the host.
    private static func herdrCommand(for host: HostConfig, arguments: [String]) -> HostCommand {
        if let ssh = host.ssh {
            let remoteCommand = "\(host.herdrPath) \(arguments.joined(separator: " "))"
            return HostCommand(
                executable: "/usr/bin/ssh",
                arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", ssh, remoteCommand])
        }
        return HostCommand(executable: host.herdrPath, arguments: arguments)
    }

    public static func sessionList(for host: HostConfig) -> HostCommand {
        herdrCommand(for: host, arguments: ["session", "list", "--json"])
    }

    /// Moves Herdr's focus onto one Agent's pane. Focus lives on the Herdr
    /// server, so every client attached to the Session follows it — including
    /// one that attaches a moment later.
    public static func agentFocus(for host: HostConfig, session: String, paneId: String) -> HostCommand {
        herdrCommand(for: host, arguments: ["--session", session, "agent", "focus", paneId])
    }
}
