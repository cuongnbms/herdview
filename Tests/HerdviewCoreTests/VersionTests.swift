import XCTest
@testable import HerdviewCore

final class VersionTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertEqual(Herdview.version, "0.1.0")
    }
}
