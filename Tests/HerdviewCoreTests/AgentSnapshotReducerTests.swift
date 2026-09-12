import XCTest
@testable import HerdviewCore

final class AgentSnapshotReducerTests: XCTestCase {
    private func info(_ pane: String, _ status: AgentStatus, revision: UInt64 = 1, cwd: String? = nil) -> AgentInfo {
        AgentInfo(paneId: pane, workspaceId: "w1", cwd: cwd, agentStatus: status, revision: revision)
    }

    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 1_010)

    func testNewAgentGetsSinceNowAndNoTransition() {
        let r = AgentSnapshotReducer.reduce(previous: [], snapshot: [info("w1:p1", .working)], host: "local", session: "default", now: t0)
        XCTAssertEqual(r.agents.count, 1)
        XCTAssertEqual(r.agents[0].key, "local/default/w1:p1")
        XCTAssertEqual(r.agents[0].host, "local")
        XCTAssertEqual(r.agents[0].session, "default")
        XCTAssertEqual(r.agents[0].status, .working)
        XCTAssertEqual(r.agents[0].since, t0)
        XCTAssertTrue(r.transitions.isEmpty)
    }

    func testStatusChangeResetsSinceAndEmitsTransition() {
        let first = AgentSnapshotReducer.reduce(previous: [], snapshot: [info("w1:p1", .working)], host: "local", session: "default", now: t0)
        let r = AgentSnapshotReducer.reduce(previous: first.agents, snapshot: [info("w1:p1", .blocked, revision: 2)], host: "local", session: "default", now: t1)
        XCTAssertEqual(r.agents[0].status, .blocked)
        XCTAssertEqual(r.agents[0].since, t1)
        XCTAssertEqual(r.transitions.count, 1)
        XCTAssertEqual(r.transitions[0].from, .working)
        XCTAssertEqual(r.transitions[0].to, .blocked)
        XCTAssertEqual(r.transitions[0].agent.key, "local/default/w1:p1")
    }

    func testUnchangedStatusKeepsSinceAndRefreshesInfo() {
        let first = AgentSnapshotReducer.reduce(previous: [], snapshot: [info("w1:p1", .working, cwd: "/a")], host: "local", session: "default", now: t0)
        let r = AgentSnapshotReducer.reduce(previous: first.agents, snapshot: [info("w1:p1", .working, revision: 2, cwd: "/b")], host: "local", session: "default", now: t1)
        XCTAssertEqual(r.agents[0].since, t0)
        XCTAssertEqual(r.agents[0].info.cwd, "/b")
        XCTAssertTrue(r.transitions.isEmpty)
    }

    func testRemovedAgentIsDroppedWithoutTransition() {
        let first = AgentSnapshotReducer.reduce(previous: [], snapshot: [info("w1:p1", .working), info("w1:p2", .idle)], host: "local", session: "default", now: t0)
        let r = AgentSnapshotReducer.reduce(previous: first.agents, snapshot: [info("w1:p2", .idle)], host: "local", session: "default", now: t1)
        XCTAssertEqual(r.agents.map(\.info.paneId), ["w1:p2"])
        XCTAssertTrue(r.transitions.isEmpty)
    }

    func testStaleRevisionIsIgnored() {
        let first = AgentSnapshotReducer.reduce(previous: [], snapshot: [info("w1:p1", .working, revision: 5)], host: "local", session: "default", now: t0)
        let r = AgentSnapshotReducer.reduce(previous: first.agents, snapshot: [info("w1:p1", .blocked, revision: 3)], host: "local", session: "default", now: t1)
        XCTAssertEqual(r.agents[0].status, .working)
        XCTAssertEqual(r.agents[0].info.revision, 5)
        XCTAssertEqual(r.agents[0].since, t0)
        XCTAssertTrue(r.transitions.isEmpty)
    }
}
