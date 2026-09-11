import Foundation

/// One Herdr session as `herdr session list --json` prints it.
public struct HerdrSession: Decodable, Equatable, Sendable {
    public let name: String
    /// Absolute path as Herdr prints it. Never expanded or rewritten.
    public let socketPath: String
    public let running: Bool
    public let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case socketPath = "socket_path"
        case running
        case isDefault = "default"
    }

    public init(name: String, socketPath: String, running: Bool, isDefault: Bool) {
        self.name = name
        self.socketPath = socketPath
        self.running = running
        self.isDefault = isDefault
    }
}

public enum SessionDiscovery {
    private struct Output: Decodable {
        let sessions: [HerdrSession]
    }

    public static func parse(_ data: Data) throws -> [HerdrSession] {
        try JSONDecoder().decode(Output.self, from: data).sessions
    }

    public static func running(_ sessions: [HerdrSession]) -> [HerdrSession] {
        sessions.filter(\.running)
    }
}
