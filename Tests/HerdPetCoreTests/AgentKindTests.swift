import XCTest
@testable import HerdPetCore

final class AgentKindTests: XCTestCase {
    func testHerdrLabelsMapToKinds() {
        XCTAssertEqual(AgentKind.from(label: "claude"), .claude)
        XCTAssertEqual(AgentKind.from(label: "Claude"), .claude)
        XCTAssertEqual(AgentKind.from(label: "codex"), .codex)
        XCTAssertEqual(AgentKind.from(label: "gemini"), .gemini)
        XCTAssertEqual(AgentKind.from(label: "cursor"), .cursor)
        XCTAssertEqual(AgentKind.from(label: "opencode"), .opencode)
        XCTAssertEqual(AgentKind.from(label: "windsurf"), .windsurf)
        XCTAssertEqual(AgentKind.from(label: "cli"), .cli)
        XCTAssertEqual(AgentKind.from(label: "copilot"), .copilot)
        XCTAssertEqual(AgentKind.from(label: "kiro"), .kiroCLI)
        XCTAssertEqual(AgentKind.from(label: "droid"), .droid)
        XCTAssertEqual(AgentKind.from(label: "pi"), .pi)
        XCTAssertEqual(AgentKind.from(label: "grok"), .grok)
        XCTAssertEqual(AgentKind.from(label: "agy"), .antigravity)
    }

    func testUnknownAndNilLabels() {
        XCTAssertEqual(AgentKind.from(label: "hermes"), .unknown)
        XCTAssertEqual(AgentKind.from(label: nil), .unknown)
    }
}
