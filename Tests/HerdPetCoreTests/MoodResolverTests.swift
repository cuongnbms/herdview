import XCTest
@testable import HerdPetCore

final class MoodResolverTests: XCTestCase {
    private func agent(_ pane: String, _ status: AgentStatus) -> TrackedAgent {
        TrackedAgent(host: "local", session: "default",
                     info: AgentInfo(paneId: pane, workspaceId: "w1", agentStatus: status, revision: 1),
                     since: Date())
    }

    func testEmptyIsIdle() {
        XCTAssertEqual(MoodResolver.resolve([]), .idle)
    }

    func testBlockedBeatsWorking() {
        XCTAssertEqual(MoodResolver.resolve([agent("p1", .working), agent("p2", .blocked)]), .blocked)
    }

    func testWorkingBeatsDone() {
        XCTAssertEqual(MoodResolver.resolve([agent("p1", .done), agent("p2", .working)]), .working)
    }

    func testDoneBeatsIdle() {
        XCTAssertEqual(MoodResolver.resolve([agent("p1", .idle), agent("p2", .done)]), .done)
    }

    func testUnknownCountsAsIdle() {
        XCTAssertEqual(MoodResolver.resolve([agent("p1", .unknown)]), .idle)
    }
}
