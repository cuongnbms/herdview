import Foundation

/// The pet's chatter: one pool of lines per Mood. The built-in pools are
/// AgentPet's, with its `waiting` mapped to Herdr's `blocked`. A non-empty
/// custom pool from config replaces the built-in one for that mood.
public enum BubbleLines {
    public static let defaults: [Mood: [String]] = [
        .idle: [
            "Let's grill some bugs.",
            "I miss you. Open a branch for me.",
            "Tiny commit, tiny dopamine.",
            "The build is quiet. Too quiet.",
            "Ship something small. Future you is watching.",
            "Your TODOs are pretending not to see us.",
            "No agents running. The keyboard has entered standby drama.",
            "Turn coffee into code. Carefully.",
            "Open one file. Intimidate it professionally.",
            "The repo is calm. Suspicious, but calm.",
            "Refactor lightly. Leave with dignity.",
            "One clean diff can fix the whole afternoon.",
        ],
        .working: [
            "Thinking…", "Working on it…", "On it!", "Crunching code…",
            "Hmm, let me see…", "Cooking something up…", "Deep in thought…",
            "Brain go brrr…", "Almost there…", "Wiring it up…",
        ],
        .blocked: [
            "I need you!", "Your turn 👀", "Waiting on you…", "Can you check this?",
            "Psst, need input!", "Awaiting orders…", "Help me out?", "Stuck, need you!",
        ],
        .done: [
            "All done! ✅", "Finished!", "Ta-da!", "Done and dusted!",
            "Nailed it!", "That's a wrap!", "Mission complete!",
        ],
    ]

    /// The lines for `mood`: the custom pool when it has any non-blank line,
    /// else the built-in pool.
    public static func pool(for mood: Mood, custom: [Mood: [String]] = [:]) -> [String] {
        let lines = (custom[mood] ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.isEmpty ? (defaults[mood] ?? []) : lines
    }

    /// A line from the pool chosen by `seed`, so callers get a stable pick for
    /// the same seed and a spread of picks across different seeds.
    public static func line(for mood: Mood, custom: [Mood: [String]] = [:], seed: Int) -> String {
        let lines = pool(for: mood, custom: custom)
        guard !lines.isEmpty else { return "" }
        return lines[abs(seed) % lines.count]
    }
}
