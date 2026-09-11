import Foundation

/// The pet sprite's edge length on screen, in points. The panel sizes itself
/// from this, so it is the only knob the size control touches.
public enum PetSize {
    public static let minimum: Double = 60
    public static let maximum: Double = 240
    /// Matches the sprite size HerdPet shipped with before the size control.
    public static let defaultPoint: Double = 110

    public struct Preset: Equatable, Sendable, Identifiable {
        public let name: String
        public let point: Double
        public var id: String { name }

        public init(name: String, point: Double) {
            self.name = name
            self.point = point
        }
    }

    public static let presets: [Preset] = [
        Preset(name: "S", point: 84),
        Preset(name: "M", point: 120),
        Preset(name: "L", point: 168),
    ]

    /// Keeps a point size inside the allowed range; a non-finite value (an
    /// empty or corrupt default) falls back to the default size.
    public static func clamp(_ point: Double) -> Double {
        guard point.isFinite else { return defaultPoint }
        return min(max(point, minimum), maximum)
    }
}
