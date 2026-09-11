import XCTest
@testable import HerdPetCore

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

    func testNameWinsOverTerminalTitle() {
        let info = info(name: "handoff-b2-track-c-deliver",
                        terminalTitleStripped: "B2 track C delivery handoff")
        XCTAssertEqual(AgentTitles.baseTitle(for: info), "handoff-b2-track-c-deliver")
    }

    func testStrippedTerminalTitleBeatsRaw() {
        let info = info(terminalTitle: "raw with \u{1B}[0m escapes",
                        terminalTitleStripped: "MME forecast integration")
        XCTAssertEqual(AgentTitles.baseTitle(for: info), "MME forecast integration")
    }

    func testRawTerminalTitleUsedWhenStrippedMissing() {
        let info = info(terminalTitle: "Some title")
        XCTAssertEqual(AgentTitles.baseTitle(for: info), "Some title")
    }

    func testBlankValuesAreSkipped() {
        let info = info(name: "  ", terminalTitleStripped: "", cwd: "/home/me/bmx-core-service")
        XCTAssertEqual(AgentTitles.baseTitle(for: info), "bmx-core-service")
    }

    func testCwdBasenameBeatsPaneId() {
        let info = info(cwd: "/home/cuongnb/Workspace/works/linkbee/blue-matrix/bmx-core-service")
        XCTAssertEqual(AgentTitles.baseTitle(for: info), "bmx-core-service")
    }

    func testPaneIdIsLastResort() {
        XCTAssertEqual(AgentTitles.baseTitle(for: info(paneId: "w1:p9")), "w1:p9")
    }

    func testDecodesTerminalTitles() throws {
        let json = """
        {"id":"q","result":{"type":"agent_list","agents":[
          {"agent_status":"idle","workspace_id":"w2","pane_id":"w2:p1","revision":6,
           "terminal_title":"✳ Track a việc cần làm, mục B2",
           "terminal_title_stripped":"Track a việc cần làm, mục B2"}
        ]}}
        """
        let result = try HerdrProtocol.decodeResult(Data(json.utf8), as: AgentListResult.self)
        let a = result.agents[0]
        XCTAssertEqual(a.terminalTitle, "✳ Track a việc cần làm, mục B2")
        XCTAssertEqual(a.terminalTitleStripped, "Track a việc cần làm, mục B2")
        XCTAssertEqual(a.displayName, "Track a việc cần làm, mục B2")
    }

    func testDuplicateTitlesOnSameHostGetPaneSuffix() {
        let agents = [
            tracked(info: info(paneId: "w2:p3", terminalTitleStripped: "π - bmx-core-service")),
            tracked(info: info(paneId: "w2:p6", terminalTitleStripped: "π - bmx-core-service")),
        ]
        let names = AgentTitles.displayNames(for: agents)
        XCTAssertEqual(names[agents[0].key], "π - bmx-core-service · p3")
        XCTAssertEqual(names[agents[1].key], "π - bmx-core-service · p6")
    }

    func testSameTitleOnDifferentHostsIsNotSuffixed() {
        let agents = [
            tracked(host: "a", info: info(terminalTitleStripped: "π - svc")),
            tracked(host: "b", info: info(terminalTitleStripped: "π - svc")),
        ]
        let names = AgentTitles.displayNames(for: agents)
        XCTAssertEqual(names[agents[0].key], "π - svc")
        XCTAssertEqual(names[agents[1].key], "π - svc")
    }

    func testUniqueTitlesAreUnchanged() {
        let agents = [
            tracked(info: info(paneId: "w2:p1", terminalTitleStripped: "Track a việc cần làm")),
            tracked(info: info(paneId: "w2:p5", terminalTitleStripped: "MME forecast integration")),
        ]
        let names = AgentTitles.displayNames(for: agents)
        XCTAssertEqual(names[agents[0].key], "Track a việc cần làm")
        XCTAssertEqual(names[agents[1].key], "MME forecast integration")
    }

    func testShortPaneId() {
        XCTAssertEqual(AgentTitles.shortPaneId("w2:p6"), "p6")
        XCTAssertEqual(AgentTitles.shortPaneId("p6"), "p6")
    }
}
