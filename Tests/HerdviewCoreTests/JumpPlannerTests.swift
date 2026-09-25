import XCTest
@testable import HerdviewCore

final class JumpPlannerTests: XCTestCase {
    private let local = HostConfig(name: "local", ssh: nil, herdrPath: "/opt/homebrew/bin/herdr", pollSeconds: 2)
    private let devtuf = HostConfig(name: "devtuf", ssh: "devtuf", herdrPath: "/home/cuongnb/.local/bin/herdr", pollSeconds: 2)
    private let herdr = "/opt/homebrew/bin/herdr"

    private let tree = CmuxTree(workspaces: [
        .init(ref: "workspace:2", title: "Generals", surfaces: [
            .init(ref: "surface:45", tty: "ttys012"),
            .init(ref: "surface:47", tty: "ttys016"),
        ]),
        .init(ref: "workspace:5", title: "blue-matrix", surfaces: [.init(ref: "surface:7", tty: "ttys006")]),
        .init(ref: "workspace:6", title: "Blue Matrix", surfaces: [.init(ref: "surface:24", tty: "ttys004")]),
        .init(ref: "workspace:8", title: "Carex", surfaces: [.init(ref: "surface:10", tty: "ttys000")]),
    ])

    func testFocusesTheTabAttachedToTheSession() {
        let attachments = [HerdrAttachment(tty: "ttys000", remote: "devtuf", session: "carex")]
        XCTAssertEqual(JumpPlanner.plan(host: devtuf, session: "carex", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .focus(surface: "surface:10"))
    }

    func testBareHerdrIsTheLocalDefaultSession() {
        let attachments = [HerdrAttachment(tty: "ttys016", remote: nil, session: "default")]
        XCTAssertEqual(JumpPlanner.plan(host: local, session: "default", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .focus(surface: "surface:47"))
    }

    func testSeveralTabsPreferTheOneInTheMatchingWorkspace() {
        let attachments = [
            HerdrAttachment(tty: "ttys012", remote: "devtuf", session: "carex"),
            HerdrAttachment(tty: "ttys000", remote: "devtuf", session: "carex"),
        ]
        XCTAssertEqual(JumpPlanner.plan(host: devtuf, session: "carex", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .focus(surface: "surface:10"))
    }

    func testSeveralTabsOutsideAnyMatchingWorkspaceTakeTheFirstInTreeOrder() {
        let attachments = [
            HerdrAttachment(tty: "ttys000", remote: "devtuf", session: "pegabot"),
            HerdrAttachment(tty: "ttys012", remote: "devtuf", session: "pegabot"),
        ]
        XCTAssertEqual(JumpPlanner.plan(host: devtuf, session: "pegabot", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .focus(surface: "surface:45"))
    }

    func testOneTtyOnTwoSurfacesTakesTheFirstInTreeOrder() {
        // cmux can report a restored surface with a stale tty that another
        // surface now holds; the planner does not tell them apart.
        let tree = CmuxTree(workspaces: [
            .init(ref: "workspace:1", title: "Generals", surfaces: [.init(ref: "surface:3", tty: "ttys000")]),
            .init(ref: "workspace:2", title: "Blue Matrix", surfaces: [.init(ref: "surface:9", tty: "ttys000")]),
        ])
        let attachments = [HerdrAttachment(tty: "ttys000", remote: "devtuf", session: "carex")]
        XCTAssertEqual(JumpPlanner.plan(host: devtuf, session: "carex", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .focus(surface: "surface:3"))
    }

    func testOneTtyOnTwoSurfacesPrefersTheOneInTheMatchingWorkspace() {
        let tree = CmuxTree(workspaces: [
            .init(ref: "workspace:1", title: "Generals", surfaces: [.init(ref: "surface:3", tty: "ttys000")]),
            .init(ref: "workspace:2", title: "Carex", surfaces: [.init(ref: "surface:9", tty: "ttys000")]),
        ])
        let attachments = [HerdrAttachment(tty: "ttys000", remote: "devtuf", session: "carex")]
        XCTAssertEqual(JumpPlanner.plan(host: devtuf, session: "carex", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .focus(surface: "surface:9"))
    }

    func testRemoteClientMatchesOnlyItsOwnSSHValue() {
        let attachments = [HerdrAttachment(tty: "ttys000", remote: "devtuf", session: "carex")]
        let other = HostConfig(name: "devtuf", ssh: "cuongnb@devtuf", herdrPath: "/x/herdr", pollSeconds: 2)
        XCTAssertEqual(JumpPlanner.plan(host: other, session: "carex", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .newTab(workspace: "workspace:8", command: "/opt/homebrew/bin/herdr --remote cuongnb@devtuf --session carex"))
    }

    func testRemoteClientDoesNotCountForALocalSessionOfTheSameName() {
        let attachments = [HerdrAttachment(tty: "ttys000", remote: "devtuf", session: "carex")]
        XCTAssertEqual(JumpPlanner.plan(host: local, session: "carex", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .newTab(workspace: "workspace:8", command: "/opt/homebrew/bin/herdr --session carex"))
    }

    func testClientOnATtyCmuxDoesNotHoldIsIgnored() {
        let attachments = [HerdrAttachment(tty: "ttys099", remote: "devtuf", session: "carex")]
        XCTAssertEqual(JumpPlanner.plan(host: devtuf, session: "carex", attachments: attachments, tree: tree, localHerdrPath: herdr),
                       .newTab(workspace: "workspace:8", command: "/opt/homebrew/bin/herdr --remote devtuf --session carex"))
    }

    func testNoTabOpensOneInTheMatchingWorkspacePreferringAVerbatimTitle() {
        XCTAssertEqual(JumpPlanner.plan(host: devtuf, session: "blue-matrix", attachments: [], tree: tree, localHerdrPath: herdr),
                       .newTab(workspace: "workspace:5", command: "/opt/homebrew/bin/herdr --remote devtuf --session blue-matrix"))
    }

    func testNoTabAndNoWorkspaceCreatesAWorkspaceNamedAfterTheSession() {
        XCTAssertEqual(JumpPlanner.plan(host: devtuf, session: "pegabot", attachments: [], tree: tree, localHerdrPath: herdr),
                       .newWorkspace(name: "pegabot", command: "/opt/homebrew/bin/herdr --remote devtuf --session pegabot"))
    }

    func testMatchingWorkspaceWithoutAVerbatimTitleTakesTheFirst() {
        let tree = CmuxTree(workspaces: [
            .init(ref: "workspace:1", title: "Blue Matrix", surfaces: []),
            .init(ref: "workspace:2", title: "BLUE  MATRIX", surfaces: []),
        ])
        XCTAssertEqual(JumpPlanner.matchingWorkspace(for: "blue-matrix", in: tree)?.ref, "workspace:1")
    }

    func testNormalizedTitle() {
        XCTAssertEqual(JumpPlanner.normalizedTitle("Carex"), "carex")
        XCTAssertEqual(JumpPlanner.normalizedTitle("PegaBot"), "pegabot")
        XCTAssertEqual(JumpPlanner.normalizedTitle("  Blue   Matrix "), "blue-matrix")
        XCTAssertEqual(JumpPlanner.normalizedTitle("News\tIntelligence"), "news-intelligence")
    }

    func testAttachCommand() {
        XCTAssertEqual(JumpPlanner.attachCommand(host: local, session: "remora", localHerdrPath: herdr),
                       "/opt/homebrew/bin/herdr --session remora")
        XCTAssertEqual(JumpPlanner.attachCommand(host: devtuf, session: "carex", localHerdrPath: "herdr"),
                       "herdr --remote devtuf --session carex")
    }
}
