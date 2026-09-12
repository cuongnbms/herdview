import XCTest
@testable import HerdviewCore

final class HostCommandTests: XCTestCase {
    func testLocalHostRunsHerdrDirectly() {
        let host = HostConfig(name: "local", ssh: nil, herdrPath: "/opt/homebrew/bin/herdr", pollSeconds: 2)
        XCTAssertEqual(HostCommand.sessionList(for: host), HostCommand(executable: "/opt/homebrew/bin/herdr", arguments: ["session", "list", "--json"]))
    }

    func testRemoteHostRunsOverSSH() {
        let host = HostConfig(name: "devtuf", ssh: "cuongnb@devtuf", herdrPath: "/home/cuongnb/.local/bin/herdr", pollSeconds: 2)
        XCTAssertEqual(HostCommand.sessionList(for: host), HostCommand(
            executable: "/usr/bin/ssh",
            arguments: ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "cuongnb@devtuf", "/home/cuongnb/.local/bin/herdr session list --json"]))
    }
}
