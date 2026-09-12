import XCTest
@testable import HerdviewCore

final class SessionDiscoveryTests: XCTestCase {
    static let fixture = """
    {"sessions":[{"default":true,"name":"default","running":false,"session_dir":"/home/cuongnb/.config/herdr","socket_path":"/home/cuongnb/.config/herdr/herdr.sock"},{"default":false,"name":"agent-workspace","running":false,"session_dir":"/home/cuongnb/.config/herdr/sessions/agent-workspace","socket_path":"/home/cuongnb/.config/herdr/sessions/agent-workspace/herdr.sock"},{"default":false,"name":"ail-sourcecode","running":true,"session_dir":"/home/cuongnb/.config/herdr/sessions/ail-sourcecode","socket_path":"/home/cuongnb/.config/herdr/sessions/ail-sourcecode/herdr.sock"},{"default":false,"name":"blue-matrix","running":true,"session_dir":"/home/cuongnb/.config/herdr/sessions/blue-matrix","socket_path":"/home/cuongnb/.config/herdr/sessions/blue-matrix/herdr.sock"}]}
    """

    func testParsesEverySession() throws {
        let sessions = try SessionDiscovery.parse(Data(Self.fixture.utf8))
        XCTAssertEqual(sessions.count, 4)
        XCTAssertEqual(sessions[0], HerdrSession(name: "default", socketPath: "/home/cuongnb/.config/herdr/herdr.sock", running: false, isDefault: true))
        XCTAssertEqual(sessions[2].socketPath, "/home/cuongnb/.config/herdr/sessions/ail-sourcecode/herdr.sock")
        XCTAssertTrue(sessions.allSatisfy { $0.socketPath.hasPrefix("/") })
    }

    func testRunningFilterKeepsOnlyRunningSessions() throws {
        let sessions = try SessionDiscovery.parse(Data(Self.fixture.utf8))
        XCTAssertEqual(SessionDiscovery.running(sessions).map(\.name), ["ail-sourcecode", "blue-matrix"])
    }

    func testGarbageThrows() {
        XCTAssertThrowsError(try SessionDiscovery.parse(Data("not json".utf8)))
    }
}
