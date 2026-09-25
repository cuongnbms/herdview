import XCTest
@testable import HerdviewCore

final class CmuxCommandTests: XCTestCase {
    private let cmux = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    func testTree() {
        XCTAssertEqual(CmuxCommand.tree, HostCommand(executable: cmux, arguments: ["--json", "tree", "--all"]))
    }

    func testFocus() {
        XCTAssertEqual(CmuxCommand.perform(.focus(surface: "surface:10")), HostCommand(
            executable: cmux, arguments: ["rpc", "surface.focus", #"{"surface_id":"surface:10"}"#]))
    }

    func testNewTab() {
        XCTAssertEqual(CmuxCommand.perform(.newTab(workspace: "workspace:8", command: "herdr --session carex")), HostCommand(
            executable: cmux,
            arguments: ["new-surface", "--workspace", "workspace:8", "--command", "herdr --session carex", "--focus", "true"]))
    }

    func testNewWorkspace() {
        XCTAssertEqual(CmuxCommand.perform(.newWorkspace(name: "pegabot", command: "herdr --remote devtuf --session pegabot")), HostCommand(
            executable: cmux,
            arguments: ["new-workspace", "--name", "pegabot", "--command", "herdr --remote devtuf --session pegabot", "--focus", "true"]))
    }

    func testBundleIdentifier() {
        XCTAssertEqual(CmuxCommand.bundleIdentifier, "com.cmuxterm.app")
    }
}
