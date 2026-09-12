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
    var tint: Color {
        switch self {
        case .blocked: return Color(nsColor: .systemOrange)
        case .working: return Color(nsColor: .systemGreen)
        case .done: return Color(nsColor: .systemBlue)
        case .idle, .unknown: return Color(nsColor: .systemGray)
        }
    }

    /// Whether a row in this status blinks. Both statuses here are asking for
    /// a person — one to unblock the agent, one to collect what it finished —
    /// and the movement is what you are meant to catch from across the desk.
    var blinks: Bool {
        self == .blocked || self == .done
    }

    /// How strongly a row wears its own colour on this half of the blink. The
    /// dim end is not zero: a row that vanished into the background between
    /// beats would read as a list flickering rather than as one agent asking.
    func rowFillOpacity(bright: Bool) -> Double {
        guard blinks else { return 0 }
        return bright ? 0.24 : 0.05
    }
}
