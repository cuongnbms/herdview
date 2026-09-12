import XCTest
@testable import HerdviewCore

final class SessionDiffTests: XCTestCase {
    private func session(_ name: String, running: Bool) -> HerdrSession {
        HerdrSession(name: name, socketPath: "/s/\(name).sock", running: running, isDefault: false)
    }

    func testStartsNewRunningAndStopsGone() {
        let diff = SessionDiff.compute(
            watching: ["a", "b"],
            discovered: [session("a", running: true), session("b", running: false), session("c", running: true), session("d", running: false)])
        XCTAssertEqual(diff.start.map(\.name), ["c"])
        XCTAssertEqual(diff.stop, ["b"])
    }

    func testSessionMissingFromDiscoveryIsStopped() {
        let diff = SessionDiff.compute(watching: ["a"], discovered: [])
        XCTAssertTrue(diff.start.isEmpty)
        XCTAssertEqual(diff.stop, ["a"])
    }
}
