import XCTest
@testable import HerdPetCore

final class SSHForwardSpecTests: XCTestCase {
    func testArguments() {
        let spec = SSHForwardSpec(sshTarget: "devtuf", localSocketPath: "/Users/me/.herdpet/sock/devtuf-blue.sock",
                                  remoteSocketPath: "/home/cuongnb/.config/herdr/sessions/blue/herdr.sock")
        XCTAssertEqual(SSHForwardSpec.executable, "/usr/bin/ssh")
        XCTAssertEqual(spec.arguments, [
            "-N",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "BatchMode=yes",
            "-L", "/Users/me/.herdpet/sock/devtuf-blue.sock:/home/cuongnb/.config/herdr/sessions/blue/herdr.sock",
            "devtuf",
        ])
    }

    func testLocalSocketPathSanitizesNames() {
        XCTAssertEqual(SSHForwardSpec.localSocketPath(baseDir: "/tmp/s", host: "dev tuf", session: "a/b:c"), "/tmp/s/dev_tuf-a_b_c.sock")
        XCTAssertEqual(SSHForwardSpec.localSocketPath(baseDir: "/tmp/s", host: "devtuf", session: "blue-matrix.v2"), "/tmp/s/devtuf-blue-matrix.v2.sock")
    }
}
