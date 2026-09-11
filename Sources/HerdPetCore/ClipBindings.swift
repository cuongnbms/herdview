import Foundation

/// Which spritesheet clip each Mood animates, for one pet pack. Packs number
/// their rows differently, so a binding only means something next to the pack
/// it was made for; `[clips]` in the config is the fallback for unbound moods.
public struct ClipBindings: Equatable, Sendable {
    public private(set) var byMood: [Mood: Int]

    public init(byMood: [Mood: Int] = [:]) {
        self.byMood = byMood
    }

    /// Reads bindings persisted as raw mood names, ignoring moods this version
    /// no longer has.
    public init(stored: [String: Int]) {
        var map: [Mood: Int] = [:]
        for (key, clip) in stored {
            guard let mood = Mood(rawValue: key) else { continue }
            map[mood] = clip
        }
        self.byMood = map
    }

    public var stored: [String: Int] {
        Dictionary(uniqueKeysWithValues: byMood.map { ($0.key.rawValue, $0.value) })
    }

    /// The clip `mood` animates: the bound one, else `fallback`, either way
    /// clamped to what the pack actually holds so a stale binding still draws.
    public func clip(for mood: Mood, fallback: Int, clipCount: Int) -> Int {
        guard clipCount > 0 else { return 0 }
        return min(max(byMood[mood] ?? fallback, 0), clipCount - 1)
    }

    public mutating func bind(_ clip: Int, to mood: Mood) {
        byMood[mood] = clip
    }
}
