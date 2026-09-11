import XCTest
@testable import HerdPetCore

final class ConfigLoaderTests: XCTestCase {
    func testFullSample() throws {
        let text = """
        pet = "boba"

        [clips]
        blocked = 3

        [[hosts]]
        name = "local"
        herdr_path = "/opt/homebrew/bin/herdr"

        [[hosts]]
        name = "devtuf"
        ssh = "devtuf"
        herdr_path = "/home/cuongnb/.local/bin/herdr"
        poll_seconds = 5
        """
        let config = try ConfigLoader.parse(text)
        XCTAssertEqual(config.pet, "boba")
        XCTAssertEqual(config.hosts.count, 2)
        XCTAssertEqual(config.hosts[0], HostConfig(name: "local", ssh: nil, herdrPath: "/opt/homebrew/bin/herdr", pollSeconds: 2))
        XCTAssertTrue(config.hosts[0].isLocal)
        XCTAssertEqual(config.hosts[1], HostConfig(name: "devtuf", ssh: "devtuf", herdrPath: "/home/cuongnb/.local/bin/herdr", pollSeconds: 5))
        XCTAssertFalse(config.hosts[1].isLocal)
        XCTAssertEqual(config.clipIndex(for: .blocked), 3)
        XCTAssertEqual(config.clipIndex(for: .idle), 0)
        XCTAssertEqual(config.clipIndex(for: .working), 1)
        XCTAssertEqual(config.clipIndex(for: .done), 3)
    }

    func testDefaultsWhenOptionalFieldsAbsent() throws {
        let config = try ConfigLoader.parse("""
        [[hosts]]
        name = "local"
        herdr_path = "/opt/homebrew/bin/herdr"
        """)
        XCTAssertNil(config.pet)
        XCTAssertEqual(config.clips, HerdPetConfig.defaultClips)
        XCTAssertEqual(config.hosts[0].pollSeconds, 2)
    }

    func testMissingHerdrPathThrows() {
        XCTAssertThrowsError(try ConfigLoader.parse("[[hosts]]\nname = \"local\"")) { error in
            XCTAssertEqual(error as? ConfigError, .missingField(host: 0, field: "herdr_path"))
        }
    }

    func testMissingNameThrows() {
        XCTAssertThrowsError(try ConfigLoader.parse("[[hosts]]\nherdr_path = \"/x\"")) { error in
            XCTAssertEqual(error as? ConfigError, .missingField(host: 0, field: "name"))
        }
    }

    func testNoHostsIsValidButEmpty() throws {
        let config = try ConfigLoader.parse("pet = \"boba\"")
        XCTAssertTrue(config.hosts.isEmpty)
    }

    func testLoadMissingFileThrowsParse() {
        XCTAssertThrowsError(try ConfigLoader.load(path: "/nonexistent/herdpet.toml")) { error in
            guard case ConfigError.parse? = error as? ConfigError else { return XCTFail("expected parse error, got \(error)") }
        }
    }
}
