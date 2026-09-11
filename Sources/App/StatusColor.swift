import SwiftUI
import HerdPetCore

extension AgentStatus {
    /// The dot colour for a status, shared by the menu list and the pet's bubble.
    var dotColor: Color {
        switch self {
        case .blocked: return .orange
        case .working: return .green
        case .done: return .blue
        case .idle, .unknown: return .gray
        }
    }
}
