import XCTest
@testable import HerdviewCore

final class RecentCreationsTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testASessionNothingWasCreatedForIsNotCovered() {
        let recent = RecentCreations()
        XCTAssertFalse(recent.covers(host: "devtuf", session: "carex", now: start))
    }

    func testACreateCoversTheSameSessionUntilTheWindowEnds() {
        var recent = RecentCreations()
        recent.record(host: "devtuf", session: "carex", now: start)
        XCTAssertTrue(recent.covers(host: "devtuf", session: "carex", now: start))
        XCTAssertTrue(recent.covers(host: "devtuf", session: "carex", now: start + RecentCreations.window - 0.1))
        XCTAssertFalse(recent.covers(host: "devtuf", session: "carex", now: start + RecentCreations.window))
    }

    func testACreateCoversOnlyItsOwnHostAndSession() {
        var recent = RecentCreations()
        recent.record(host: "devtuf", session: "carex", now: start)
        XCTAssertFalse(recent.covers(host: "local", session: "carex", now: start))
        XCTAssertFalse(recent.covers(host: "devtuf", session: "pegabot", now: start))
    }

    func testOnlyTabAndWorkspacePlansCreate() {
        XCTAssertFalse(JumpPlan.focus(surface: "surface:10").creates)
        XCTAssertTrue(JumpPlan.newTab(workspace: "workspace:8", command: "herdr").creates)
        XCTAssertTrue(JumpPlan.newWorkspace(name: "carex", command: "herdr").creates)
    }
}
