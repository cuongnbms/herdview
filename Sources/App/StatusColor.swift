import SwiftUI
import HerdPetCore

extension AgentStatus {
    /// The one colour that carries this status everywhere it shows up: the
    /// summary chips, the status pill, and the tint a row flashes on a
    /// transition. System colours rather than fixed hex, so dark mode and the
    /// Increase Contrast setting come for free.
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

    /// How strongly a row wears its own colour when nothing is flashing. Only
    /// blocked agents are warm across the whole row; that band of colour down
    /// the list is the thing you are meant to catch from across the desk.
    var restingRowOpacity: Double {
        self == .blocked ? 0.10 : 0
    }
}
