import XCTest
@testable import HerdviewCore

final class HerdrProtocolTests: XCTestCase {
    func testRequestLineHasIdMethodEmptyParamsAndNewline() throws {
        let line = try HerdrProtocol.requestLine(id: "req_1", method: "agent.list")
        XCTAssertEqual(line.last, 0x0A)
        let obj = try JSONSerialization.jsonObject(with: line.dropLast()) as? [String: Any]
        XCTAssertEqual(obj?["id"] as? String, "req_1")
        XCTAssertEqual(obj?["method"] as? String, "agent.list")
        XCTAssertEqual((obj?["params"] as? [String: Any])?.count, 0)
    }

    func testDecodeAgentListIgnoresUnknownFields() throws {
        let json = """
        {"id":"req_1","result":{"type":"agent_list","agents":[
          {"terminal_id":"term_1","agent_status":"working","workspace_id":"w1","tab_id":"t1",
           "pane_id":"w1:p1","focused":true,"revision":42,"agent":"claude","display_agent":"Claude Code",
           "name":"reviewer","cwd":"/home/me/proj","tokens":{},"state_labels":{},"interactive_ready":true}
        ]}}
        """
        let result = try HerdrProtocol.decodeResult(Data(json.utf8), as: AgentListResult.self)
        XCTAssertEqual(result.agents.count, 1)
        let a = result.agents[0]
        XCTAssertEqual(a.paneId, "w1:p1")
        XCTAssertEqual(a.workspaceId, "w1")
        XCTAssertEqual(a.tabId, "t1")
        XCTAssertEqual(a.agent, "claude")
        XCTAssertEqual(a.displayAgent, "Claude Code")
        XCTAssertEqual(a.name, "reviewer")
        XCTAssertEqual(a.cwd, "/home/me/proj")
        XCTAssertEqual(a.agentStatus, .working)
        XCTAssertEqual(a.revision, 42)
    }

    func testMinimalRecordDecodesWithOptionalFieldsNil() throws {
        let json = """
        {"id":"r","result":{"type":"agent_list","agents":[
          {"agent_status":"idle","workspace_id":"w1","pane_id":"w1:p2","revision":1}
        ]}}
        """
        let result = try HerdrProtocol.decodeResult(Data(json.utf8), as: AgentListResult.self)
        XCTAssertEqual(result.agents[0].paneId, "w1:p2")
        XCTAssertNil(result.agents[0].name)
        XCTAssertNil(result.agents[0].cwd)
    }

    func testUnknownStatusDecodesAsUnknown() throws {
        let json = """
        {"id":"r","result":{"type":"agent_list","agents":[
          {"agent_status":"something_new","workspace_id":"w1","pane_id":"w1:p1","revision":1}
        ]}}
        """
        let result = try HerdrProtocol.decodeResult(Data(json.utf8), as: AgentListResult.self)
        XCTAssertEqual(result.agents[0].agentStatus, .unknown)
    }

    func testErrorEnvelopeThrowsHerdrError() {
        let json = #"{"id":"r","error":{"code":"not_found","message":"pane not found"}}"#
        XCTAssertThrowsError(try HerdrProtocol.decodeResult(Data(json.utf8), as: AgentListResult.self)) { error in
            XCTAssertEqual(error as? HerdrError, HerdrError(code: "not_found", message: "pane not found"))
        }
    }
}
