import XCTest
@testable import HerdviewCore

final class TransitionNoticeTests: XCTestCase {
    private func agent(host: String = "devtuf", session: String = "default",
                       pane: String = "w2:p1", status: AgentStatus,
                       name: String? = nil, cwd: String? = "/home/me/linkbee/bmx-core-service") -> TrackedAgent {
        let info = AgentInfo(paneId: pane, workspaceId: "w2", name: name,
                             terminalTitleStripped: "MME forecast integration",
                             cwd: cwd, agentStatus: status, revision: 4)
        return TrackedAgent(host: host, session: session, info: info, since: Date())
    }

    private func transition(from: AgentStatus, to: AgentStatus,
                            host: String = "devtuf", session: String = "default",
                            pane: String = "w2:p1", cwd: String? = "/home/me/linkbee/bmx-core-service") -> Transition {
        Transition(agent: agent(host: host, session: session, pane: pane, status: to, cwd: cwd),
                   from: from, to: to)
    }

    /// A banner says the same three things the row says, in the same order, so
    /// the notification and the window never name one agent two ways.
    func testBlockedReadsLikeTheRow() throws {
        let notice = try XCTUnwrap(TransitionNotice(transition(from: .working, to: .blocked)))
        XCTAssertEqual(notice.title, "bmx-core-service (default)")
        XCTAssertEqual(notice.subtitle, "blocked on devtuf")
        XCTAssertEqual(notice.body, "MME forecast integration")
    }

    func testDoneNotifiesToo() throws {
        let notice = try XCTUnwrap(TransitionNotice(transition(from: .working, to: .done)))
        XCTAssertEqual(notice.subtitle, "done on devtuf")
    }

    /// Only the two statuses that are asking for a person get a banner. The
    /// others flip back and forth every poll and would say nothing worth
    /// interrupting for.
    func testOnlyBlockedAndDoneAreWorthInterruptingFor() {
        XCTAssertNil(TransitionNotice(transition(from: .blocked, to: .working)))
        XCTAssertNil(TransitionNotice(transition(from: .working, to: .idle)))
        XCTAssertNil(TransitionNotice(transition(from: .done, to: .working)))
        XCTAssertNil(TransitionNotice(transition(from: .blocked, to: .unknown)))
    }

    /// Where the agent came from never matters: an agent that goes straight
    /// from idle to blocked is asking just as loudly.
    func testAnyStatusCanLeadIntoABanner() {
        for from in AgentStatus.allCases where from != .blocked {
            XCTAssertNotNil(TransitionNotice(transition(from: from, to: .blocked)),
                            "\(from) -> blocked produced no notice")
        }
    }

    /// One agent gets one banner. Going blocked, then done, then blocked again
    /// replaces what is on screen rather than stacking three banners up.
    func testABannerIsIdentifiedByItsAgentSoItReplacesItsOwn() throws {
        let first = try XCTUnwrap(TransitionNotice(transition(from: .working, to: .blocked)))
        let second = try XCTUnwrap(TransitionNotice(transition(from: .blocked, to: .done)))
        XCTAssertEqual(first.identifier, "devtuf/default/w2:p1")
        XCTAssertEqual(second.identifier, first.identifier)

        let other = try XCTUnwrap(TransitionNotice(transition(from: .working, to: .blocked, pane: "w2:p6")))
        XCTAssertNotEqual(other.identifier, first.identifier)
    }

    /// Banners group by host, the way the window's sections do.
    func testBannersGroupByHost() throws {
        let notice = try XCTUnwrap(TransitionNotice(transition(from: .working, to: .blocked, host: "local")))
        XCTAssertEqual(notice.threadIdentifier, "local")
        XCTAssertEqual(notice.subtitle, "blocked on local")
    }

    /// With no working directory the session is already the title, so it must
    /// not be repeated in brackets after itself.
    func testSessionIsNotPrintedTwiceWhenItLeads() throws {
        let notice = try XCTUnwrap(TransitionNotice(transition(from: .working, to: .blocked,
                                                               session: "blue-matrix", cwd: nil)))
        XCTAssertEqual(notice.title, "blue-matrix")
        XCTAssertEqual(notice.subtitle, "blocked on devtuf")
    }
}
