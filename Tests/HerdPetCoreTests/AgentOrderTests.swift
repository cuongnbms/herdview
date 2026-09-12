import XCTest
@testable import HerdPetCore

final class AgentOrderTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 1_010)

    private func agent(_ pane: String, _ status: AgentStatus, since: Date, session: String = "default") -> TrackedAgent {
        TrackedAgent(host: "local", session: session,
                     info: AgentInfo(paneId: pane, workspaceId: "w1", agentStatus: status, revision: 1),
                     since: since)
    }

    func testAgentWaitingOnAHumanComesBeforeABusyOne() {
        let blocked = agent("w1:p1", .blocked, since: t0)
        let working = agent("w1:p2", .working, since: t1)
        XCTAssertTrue(AgentOrder.before(blocked, working))
        XCTAssertFalse(AgentOrder.before(working, blocked))
    }

    func testWithinOneStatusTheNewestComesFirst() {
        let older = agent("w1:p1", .idle, since: t0)
        let newer = agent("w1:p2", .idle, since: t1)
        XCTAssertTrue(AgentOrder.before(newer, older))
        XCTAssertFalse(AgentOrder.before(older, newer))
    }

    func testRecencyNeverOutranksAttention() {
        let freshIdle = agent("w1:p1", .idle, since: t1)
        let staleBlocked = agent("w1:p2", .blocked, since: t0)
        XCTAssertTrue(AgentOrder.before(staleBlocked, freshIdle))
    }

    func testAgentsObservedAtTheSameMomentKeepAStableOrder() {
        let first = agent("w1:p1", .idle, since: t0)
        let second = agent("w1:p2", .idle, since: t0)
        XCTAssertTrue(AgentOrder.before(first, second))
        XCTAssertFalse(AgentOrder.before(second, first))
    }

    func testSortingAListPutsTheNewestIdleAgentAtTheTopOfItsGroup() {
        let agents = [
            agent("w1:p1", .idle, since: t0),
            agent("w1:p2", .idle, since: t1),
            agent("w1:p3", .working, since: t0),
        ]
        XCTAssertEqual(agents.sorted(by: AgentOrder.before).map(\.info.paneId), ["w1:p3", "w1:p2", "w1:p1"])
    }
}
