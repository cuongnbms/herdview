import XCTest
@testable import HerdPetCore

final class VersionTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertEqual(HerdPet.version, "0.1.0")
    }
}
