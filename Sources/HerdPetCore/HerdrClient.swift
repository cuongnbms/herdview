import Foundation

/// Typed calls over `HerdrSocketClient`.
public enum HerdrClient {
    public static func agentList(socketPath: String) throws -> [AgentInfo] {
        let id = "herdpet-\(UUID().uuidString.prefix(8))"
        let line = try HerdrProtocol.requestLine(id: id, method: "agent.list")
        let response = try HerdrSocketClient.exchange(line: line, socketPath: socketPath)
        return try HerdrProtocol.decodeResult(response, as: AgentListResult.self).agents
    }
}
