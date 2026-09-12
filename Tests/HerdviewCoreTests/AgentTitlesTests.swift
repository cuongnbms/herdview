import XCTest
@testable import HerdviewCore

final class AgentTitlesTests: XCTestCase {
    private func info(paneId: String = "w2:p1", name: String? = nil,
                      terminalTitle: String? = nil, terminalTitleStripped: String? = nil,
                      cwd: String? = nil) -> AgentInfo {
        AgentInfo(paneId: paneId, workspaceId: "w2", name: name,
                  terminalTitle: terminalTitle, terminalTitleStripped: terminalTitleStripped,
                  cwd: cwd, agentStatus: .idle, revision: 1)
    }

    private func tracked(host: String = "dev", session: String = "s", info: AgentInfo) -> TrackedAgent {
        TrackedAgent(host: host, session: session, info: info, since: Date())
    }

    func testDirectoryOnTopSessionAndTitleBelow() {
        let agent = tracked(session: "blue-matrix",
                            info: info(terminalTitleStripped: "Track A Ingestion Contract review",
                                       cwd: "/home/me/linkbee/bmx-core-service"))
        let text = AgentTitles.rowText(for: agent)
        XCTAssertEqual(text.primary, "bmx-core-service")
        XCTAssertEqual(text.session, "blue-matrix")
        XCTAssertEqual(text.secondary, "Track A Ingestion Contract review")
    }

    func testNameWinsOverTerminalTitle() {
        let agent = tracked(info: info(name: "handoff-b2-track-c-deliver",
                                       terminalTitleStripped: "B2 track C delivery handoff",
                                       cwd: "/home/me/svc"))
        let text = AgentTitles.rowText(for: agent)
        XCTAssertEqual(text.session, "s")
        XCTAssertEqual(text.secondary, "handoff-b2-track-c-deliver")
    }

    func testStrippedTerminalTitleBeatsRaw() {
        let agent = tracked(info: info(terminalTitle: "raw with \u{1B}[0m escapes",
                                       terminalTitleStripped: "MME forecast integration",
                                       cwd: "/home/me/svc"))
        XCTAssertEqual(AgentTitles.rowText(for: agent).secondary, "MME forecast integration")
    }

    func testRawTerminalTitleUsedWhenStrippedMissing() {
        let agent = tracked(info: info(terminalTitle: "Some title", cwd: "/home/me/svc"))
        XCTAssertEqual(AgentTitles.rowText(for: agent).secondary, "Some title")
    }

    func testBlankValuesAreSkipped() {
        let agent = tracked(info: info(paneId: "w2:p4", name: "  ", terminalTitleStripped: "",
                                       cwd: "/home/me/bmx-core-service"))
        let text = AgentTitles.rowText(for: agent)
        XCTAssertEqual(text.primary, "bmx-core-service")
        XCTAssertEqual(text.secondary, "w2:p4")
    }

    /// Without a directory the session takes the first line on its own, rather
    /// than standing next to a name that is not there.
    func testSessionLeadsWhenThereIsNoDirectory() {
        let agent = tracked(session: "blue-matrix",
                            info: info(terminalTitleStripped: "Track A Ingestion Contract review"))
        let text = AgentTitles.rowText(for: agent)
        XCTAssertEqual(text.primary, "blue-matrix")
        XCTAssertNil(text.session)
        XCTAssertEqual(text.secondary, "Track A Ingestion Contract review")
    }

    func testPaneIdIsTheLastResort() {
        let agent = tracked(info: info(paneId: "w1:p9"))
        let text = AgentTitles.rowText(for: agent)
        XCTAssertEqual(text.primary, "s")
        XCTAssertNil(text.session)
        XCTAssertEqual(text.secondary, "w1:p9")
    }

    /// Two panes in the same checkout share a first line on purpose; the
    /// second line is what tells them apart, so no pane suffix is added.
    func testPanesSharingADirectoryKeepTheirDirectoryName() {
        let agents = [
            tracked(info: info(paneId: "w2:p3", terminalTitleStripped: "π - svc", cwd: "/home/me/svc")),
            tracked(info: info(paneId: "w2:p6", cwd: "/home/me/svc")),
        ]
        XCTAssertEqual(AgentTitles.rowText(for: agents[0]).primary, "svc")
        XCTAssertEqual(AgentTitles.rowText(for: agents[1]).primary, "svc")
        XCTAssertEqual(AgentTitles.rowText(for: agents[0]).secondary, "π - svc")
        XCTAssertEqual(AgentTitles.rowText(for: agents[1]).secondary, "w2:p6")
    }

    func testDecodesTerminalTitles() throws {
        let json = """
        {"id":"q","result":{"type":"agent_list","agents":[
          {"agent_status":"idle","workspace_id":"w2","pane_id":"w2:p1","revision":6,
           "cwd":"/home/me/todo","terminal_title":"✳ Track a việc cần làm, mục B2",
           "terminal_title_stripped":"Track a việc cần làm, mục B2"}
        ]}}
        """
        let result = try HerdrProtocol.decodeResult(Data(json.utf8), as: AgentListResult.self)
        let a = result.agents[0]
        XCTAssertEqual(a.terminalTitle, "✳ Track a việc cần làm, mục B2")
        XCTAssertEqual(a.terminalTitleStripped, "Track a việc cần làm, mục B2")
        let text = AgentTitles.rowText(for: tracked(session: "default", info: a))
        XCTAssertEqual(text.primary, "todo")
        XCTAssertEqual(text.session, "default")
        XCTAssertEqual(text.secondary, "Track a việc cần làm, mục B2")
    }
    /// An agent's working directory belongs to the host the agent runs on, not
    /// to this Mac, so naming its last component must never touch the local
    /// file system. `URL(fileURLWithPath:)` does: it stats the path, and under
    /// `/home` — an autofs trigger on macOS — that stat waits on `automountd`
    /// for about ten milliseconds. The row is rebuilt several times a second
    /// for every agent in the list, so a lookup that slow freezes the window.
    func testNamesTheDirectoryWithoutAskingTheFileSystem() {
        let remote = info(cwd: "/home/me/linkbee/bmx-core-service")
        let start = Date()
        for _ in 0..<200 { _ = AgentTitles.rowText(for: tracked(info: remote)) }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.2,
                          "200 lookups took \(elapsed)s — a path under /home is being stat'd")
    }

    /// Whatever shape the remote path arrives in, the last component is what
    /// the row shows, and a path that names nothing shows nothing.
    func testDirectoryShapes() {
        func primary(_ cwd: String?) -> String {
            AgentTitles.rowText(for: tracked(info: info(cwd: cwd))).primary
        }
        XCTAssertEqual(primary("/home/me/svc"), "svc")
        XCTAssertEqual(primary("/home/me/svc/"), "svc")
        XCTAssertEqual(primary("/home/me/svc///"), "svc")
        XCTAssertEqual(primary("svc"), "svc")
        // Nothing to name: the session leads instead.
        XCTAssertEqual(primary("/"), "s")
        XCTAssertEqual(primary("///"), "s")
        XCTAssertEqual(primary("   "), "s")
        XCTAssertEqual(primary(nil), "s")
    }

}
