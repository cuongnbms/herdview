import Foundation

/// How fast the pet's clips play, as a multiplier on each mood's own frame
/// rate. The mood rates themselves are fixed; this only scales them.
public enum AnimationSpeed {
    public static let minimum: Double = 0.25
    public static let maximum: Double = 3
    /// The speed HerdPet shipped with before the control existed.
    public static let defaultMultiplier: Double = 1

    public struct Preset: Equatable, Sendable, Identifiable {
        public let name: String
        public let multiplier: Double
        public var id: String { name }

        public init(name: String, multiplier: Double) {
            self.name = name
            self.multiplier = multiplier
        }
    }

    public static let presets: [Preset] = [
        Preset(name: "0.5×", multiplier: 0.5),
        Preset(name: "1×", multiplier: 1),
        Preset(name: "2×", multiplier: 2),
    ]

    /// Keeps a multiplier inside the allowed range; a non-finite value (an
    /// empty or corrupt default) falls back to the default speed.
    public static func clamp(_ multiplier: Double) -> Double {
        guard multiplier.isFinite else { return defaultMultiplier }
        return min(max(multiplier, minimum), maximum)
    }

    /// The frame rate a mood's own `base` rate becomes at `multiplier`.
    public static func fps(base: Double, multiplier: Double) -> Double {
        base * clamp(multiplier)
    }
}
