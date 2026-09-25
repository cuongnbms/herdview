import XCTest
@testable import HerdviewCore

final class CmuxTreeTests: XCTestCase {
    private let fixture = """
    {
      "active": {"surface_ref": "surface:49", "workspace_ref": "workspace:2"},
      "windows": [
        {
          "ref": "window:1", "index": 0,
          "workspaces": [
            {
              "ref": "workspace:2", "title": "Generals", "index": 1, "pinned": false,
              "panes": [
                {"ref": "pane:2", "index": 0, "surfaces": [
                  {"ref": "surface:45", "type": "terminal", "tty": "ttys012", "title": "✳ x", "url": null},
                  {"ref": "surface:50", "type": "browser", "tty": null, "url": "https://example.com"},
                  {"ref": "surface:51", "type": "terminal", "title": "starting"}
                ]}
              ]
            },
            {
              "ref": "workspace:8", "title": "Carex", "description": null,
              "panes": [
                {"ref": "pane:8", "surfaces": [
                  {"ref": "surface:10", "type": "terminal", "tty": "ttys000", "title": "tuf: carex-core-service"}
                ]},
                {"ref": "pane:9", "surfaces": [
                  {"ref": "surface:11", "type": "terminal", "tty": "ttys001"}
                ]}
              ]
            }
          ]
        },
        {
          "ref": "window:2",
          "workspaces": [
            {"ref": "workspace:13", "title": "Other", "panes": []}
          ]
        }
      ]
    }
    """

    func testDecodesWorkspacesInTreeOrderWithTheirTerminals() throws {
        let tree = try CmuxTree.decode(Data(fixture.utf8))
        XCTAssertEqual(tree, CmuxTree(workspaces: [
            .init(ref: "workspace:2", title: "Generals", surfaces: [.init(ref: "surface:45", tty: "ttys012")]),
            .init(ref: "workspace:8", title: "Carex", surfaces: [
                .init(ref: "surface:10", tty: "ttys000"),
                .init(ref: "surface:11", tty: "ttys001"),
            ]),
            .init(ref: "workspace:13", title: "Other", surfaces: []),
        ]))
    }

    func testMissingTitleIsEmpty() throws {
        let json = #"{"windows":[{"workspaces":[{"ref":"workspace:1","panes":[]}]}]}"#
        XCTAssertEqual(try CmuxTree.decode(Data(json.utf8)),
                       CmuxTree(workspaces: [.init(ref: "workspace:1", title: "", surfaces: [])]))
    }

    func testNotJSONThrows() {
        XCTAssertThrowsError(try CmuxTree.decode(Data("cmux: socket refused".utf8)))
    }
}
