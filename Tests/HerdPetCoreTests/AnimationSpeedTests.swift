import XCTest
@testable import HerdPetCore

final class AnimationSpeedTests: XCTestCase {
    func testClampKeepsValuesInsideTheRange() {
        XCTAssertEqual(AnimationSpeed.clamp(1), 1)
        XCTAssertEqual(AnimationSpeed.clamp(AnimationSpeed.minimum), AnimationSpeed.minimum)
        XCTAssertEqual(AnimationSpeed.clamp(AnimationSpeed.maximum), AnimationSpeed.maximum)
    }

    func testClampPullsOutOfRangeValuesIn() {
        XCTAssertEqual(AnimationSpeed.clamp(0.01), AnimationSpeed.minimum)
        XCTAssertEqual(AnimationSpeed.clamp(99), AnimationSpeed.maximum)
        XCTAssertEqual(AnimationSpeed.clamp(-2), AnimationSpeed.minimum)
    }

    func testClampFallsBackForNonFiniteInput() {
        XCTAssertEqual(AnimationSpeed.clamp(.nan), AnimationSpeed.defaultMultiplier)
        XCTAssertEqual(AnimationSpeed.clamp(.infinity), AnimationSpeed.defaultMultiplier)
    }

    func testDefaultSpeedLeavesTheBaseRateAlone() {
        XCTAssertEqual(AnimationSpeed.fps(base: 3, multiplier: AnimationSpeed.defaultMultiplier), 3)
        XCTAssertEqual(AnimationSpeed.fps(base: 6, multiplier: AnimationSpeed.defaultMultiplier), 6)
    }

    func testMultiplierScalesTheBaseRate() {
        XCTAssertEqual(AnimationSpeed.fps(base: 6, multiplier: 0.5), 3)
        XCTAssertEqual(AnimationSpeed.fps(base: 3, multiplier: 2), 6)
    }

    func testFpsClampsTheMultiplierBeforeScaling() {
        XCTAssertEqual(AnimationSpeed.fps(base: 3, multiplier: 1_000), 3 * AnimationSpeed.maximum)
        XCTAssertEqual(AnimationSpeed.fps(base: 3, multiplier: 0), 3 * AnimationSpeed.minimum)
    }

    func testPresetsAreInsideTheRangeAndIncludeTheDefault() {
        for preset in AnimationSpeed.presets {
            XCTAssertEqual(AnimationSpeed.clamp(preset.multiplier), preset.multiplier, preset.name)
        }
        XCTAssertTrue(AnimationSpeed.presets.contains { $0.multiplier == AnimationSpeed.defaultMultiplier })
    }
}
