import SwiftUI
import HerdviewCore

extension AgentStatus {
    /// The one colour that carries this status everywhere it shows up: the
    /// summary chips, the status pill, and the wash a row blinks in. System
    /// colours rather than fixed hex, so dark mode and the Increase Contrast
    /// setting come for free.
    ///
    /// Colour is only ever put on a *shape* — a dot, a pill's fill, a row wash.
    /// Text stays on the label colours, because orange never reaches a readable
    /// contrast ratio against a light window at 11pt, and orange is the one
    /// colour this app cannot give up: it is what the menu bar item means.
    var tint: Color { Color(nsColor: nsTint) }

    /// The same colour as AppKit sees it. The blinking wash is drawn by a
    /// `CALayer`, which needs a `CGColor` resolved against the current
    /// appearance, so the definition lives here and `tint` is derived from it
    /// rather than the two being written out separately and drifting apart.
    var nsTint: NSColor {
        switch self {
        case .blocked: return .systemOrange
        case .working: return .systemGreen
        case .done: return .systemBlue
        case .idle, .unknown: return .systemGray
        }
    }

    /// Whether a row in this status blinks. Both statuses here are asking for
    /// a person — one to unblock the agent, one to collect what it finished —
    /// and the movement is what you are meant to catch from across the desk.
    var blinks: Bool {
        self == .blocked || self == .done
    }

    /// The two ends the row's wash breathes between, or nil for a status that
    /// does not blink. The dim end is not zero: a row that vanished into the
    /// background between beats would read as a list flickering rather than as
    /// one agent asking. The bright end has to carry a whole row of window
    /// background, so it sits well above where the status pill's fill sits on
    /// a patch the size of a word.
    var washOpacity: (dim: Double, bright: Double)? {
        guard blinks else { return nil }
        return (dim: 0.06, bright: 0.34)
    }
}
