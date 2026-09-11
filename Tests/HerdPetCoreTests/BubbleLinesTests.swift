import XCTest
@testable import HerdPetCore

final class BubbleLinesTests: XCTestCase {
    func testEveryMoodHasDefaults() {
        for mood in Mood.allCases {
            XCTAssertFalse(BubbleLines.pool(for: mood).isEmpty, "\(mood) has no default lines")
        }
    }

    func testCustomPoolReplacesDefaults() {
        let custom: [Mood: [String]] = [.blocked: ["Cần bạn!", "Tới lượt bạn"]]
        XCTAssertEqual(BubbleLines.pool(for: .blocked, custom: custom), ["Cần bạn!", "Tới lượt bạn"])
        XCTAssertEqual(BubbleLines.pool(for: .done, custom: custom), BubbleLines.defaults[.done])
    }

    func testBlankCustomLinesFallBackToDefaults() {
        XCTAssertEqual(BubbleLines.pool(for: .idle, custom: [.idle: ["", "   "]]), BubbleLines.defaults[.idle])
    }

    func testLineIsStableForSeedAndSpreadsAcrossSeeds() {
        let a = BubbleLines.line(for: .working, seed: 3)
        XCTAssertEqual(a, BubbleLines.line(for: .working, seed: 3))
        XCTAssertEqual(a, BubbleLines.defaults[.working]![3])
        XCTAssertNotEqual(a, BubbleLines.line(for: .working, seed: 4))
        XCTAssertEqual(BubbleLines.line(for: .working, seed: -1), BubbleLines.defaults[.working]![1])
    }
}
